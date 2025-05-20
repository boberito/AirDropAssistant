//
//  PrefWatcher.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/16/24.
//

import Foundation
import System
import UserNotifications
import OSLog

protocol DataModelDelegate {
    func didReceiveDataUpdate(airDropStatus: String)
}


class PrefWatcher {
    
    var delegate: DataModelDelegate?
    var notificationsAllow = false
    var eventStream: FSEventStreamRef?
    var source: DispatchSourceFileSystemObject?
    let domain = UserDefaults(suiteName: "com.apple.sharingd")
    var filePath = ""
    
    func startMonitoring() {
        
        do {
            // Open the file descriptor in event-only mode
            let fdesc = try FileDescriptor.open(filePath, .readOnly, options: .eventOnly)
            
            // Create the dispatch source
            source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fdesc.rawValue, eventMask: .all, queue: .global())
            source?.setEventHandler {
                let event = self.source?.data
                if event?.contains(.delete) == true || event?.contains(.rename) == true {
                    do {
                        // Close the existing file descriptor
                        try fdesc.close()
                        
                        // Stop the current dispatch source
                        self.source?.cancel()
                        self.source = nil
                        
                        if let ADstatus = self.domain?.string(forKey: "DiscoverableMode") {
                            self.delegate?.didReceiveDataUpdate(airDropStatus: ADstatus)
                            Logger.airdropstatus.info("Airdrop Status Changed to \(ADstatus)")
                        }
                        
                        Task {
                            await self.resetAirDrop()
                        }
                    } catch {
                        Logger.airdropstatus.error("\(error.localizedDescription)")
                    }
                } else {
                    Logger.airdropstatus.error("Something unexpected happened to the preference file")
                }
            }
            
            source?.setCancelHandler {
                
                self.startMonitoring()
            }
            
            source?.resume()
            
        } catch {
            Logger.airdropstatus.error("\(error.localizedDescription)")
        }
    }
    
    func resetAirDrop() async {
        if domain!.string(forKey: "DiscoverableMode") == UserDefaults.standard.string(forKey: "airDropSetting") || domain!.string(forKey: "DiscoverableMode") == "Off" {
            return
            
        } else {
            let ADATimer = UserDefaults.standard.integer(forKey: "timing")
            let fullTime = Double(ADATimer * 60)
            Logger.airdropstatus.info("ADA will change AirDrop Setting in \(fullTime) seconds to \(UserDefaults.standard.string(forKey: "airDropSetting") ?? "")")
            Logger.airdropstatus.info("ADA Timer Started")
            let clock = ContinuousClock()
            let now = clock.now
            let futureTime = now.advanced(by: .seconds(fullTime))
            let tolerance: Duration = .seconds(0.5)
            
            Task {
                try await Task.sleep(until: futureTime, tolerance: tolerance, clock: clock)
                self.resetDiscoverableMode()
            }
        }
    }
    func resetDiscoverableMode() {
        
        source?.cancel()
        let nc = UNUserNotificationCenter.current()
        let domain = UserDefaults(suiteName: "com.apple.sharingd")
        guard let ADASetting = UserDefaults.standard.string(forKey: "airDropSetting") else { return }
        domain?.set(ADASetting, forKey: "DiscoverableMode")
        Logger.airdropstatus.info("Airdrop Status changed by ADA to \(ADASetting)")
        var airDropInUse = true
        repeat {
            let task = Process()
            task.launchPath = "/bin/bash"
            let command = """
        /usr/sbin/lsof -c sharingd | /usr/bin/awk '$5 == "REG" && $4 ~ /[rw]/ && $9 !~ /AirDropHashDB|\\.plist|\\.loctable|\\.car|\\/System/' | /usr/bin/tail -1
        """
            task.arguments = ["-c", command]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if output == "" {
                airDropInUse = false
            } else {
                Logger.airdropstatus.info("Airdrop in use, will try again in 5 seconds.")
                airDropInUse = true
                Thread.sleep(forTimeInterval: 5)
            }
            
        } while airDropInUse
        let process = Process()
        process.launchPath = "/usr/bin/killall"
        process.arguments = ["sharingd"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        process.launch()
        process.waitUntilExit()
        if notificationsAllow{
            Task {
                let settings = await nc.notificationSettings()
                guard (settings.authorizationStatus == .authorized) ||
                        (settings.authorizationStatus == .provisional) else
                { return }
                let content = UNMutableNotificationContent()
                content.title = "AirDrop Status Changed"
                content.body = ADASetting
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                try await nc.add(request)
            }
        }
        self.startMonitoring()
        
        
    }
}
