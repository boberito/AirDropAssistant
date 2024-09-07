//
//  PrefWatcher.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/16/24.
//

import Foundation
import System
import UserNotifications

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
                        }
                        NSLog("Airdrop Status Changed")
                        self.resetAirDrop()
                    } catch {
                        
                        print(error)
                    }
                } else {
//                    print("something else")
                }
            }
            
            source?.setCancelHandler {
//                print("source canceled")
                self.startMonitoring()
            }
            
            source?.resume()
            
        } catch {
            print(error)
        }
    }
    
    func resetAirDrop()  {
        if domain!.string(forKey: "DiscoverableMode") == UserDefaults.standard.string(forKey: "airDropSetting") || domain!.string(forKey: "DiscoverableMode") == "Off" {
            return
         
        } else {
            let ADATimer = UserDefaults.standard.integer(forKey: "timing")
            let fullTime = Double(ADATimer * 60)
            NSLog("ADA Timer Started")
            DispatchQueue.main.asyncAfter(deadline: .now() + fullTime) {
                self.resetDiscoverableMode()
            }
        }
    }
    func resetDiscoverableMode() {
        NSLog("Airdrop Status changed by ADA")
        source?.cancel()
        let nc = UNUserNotificationCenter.current()
        let domain = UserDefaults(suiteName: "com.apple.sharingd")
        guard let ADASetting = UserDefaults.standard.string(forKey: "airDropSetting") else { return }
//        if let ADASetting = UserDefaults.standard.string(forKey: "airDropSetting") {
        domain?.set(ADASetting, forKey: "DiscoverableMode")
//        }
        
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
