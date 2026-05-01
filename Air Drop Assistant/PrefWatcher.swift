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

// MARK: - PrefWatcher Overview
// Watches the sharingd preference file for changes and enforces the configured
// AirDrop DiscoverableMode after a configurable delay. Also posts local notifications
// when status changes, if permitted.

/// Convenience to render human-readable strings for DispatchSource filesystem events.
extension DispatchSourceFileSystemObject {
    var dataStrings: [String] {
        var s = [String]()
        if data.contains(.all)      { s.append("all") }
        if data.contains(.attrib)   { s.append("attrib") }
        if data.contains(.delete)   { s.append("delete") }
        if data.contains(.extend)   { s.append("extend") }
        if data.contains(.funlock)  { s.append("funlock") }
        if data.contains(.link)     { s.append("link") }
        if data.contains(.rename)   { s.append("rename") }
        if data.contains(.revoke)   { s.append("revoke") }
        if data.contains(.write)    { s.append("write") }
        return s
    }
}

/// Delegate for reporting AirDrop status updates to the app (e.g., to rebuild the menu).
protocol DataModelDelegate {
    func didReceiveDataUpdate(airDropStatus: String)
}

/// Encapsulates file monitoring of the sharingd preferences and logic to reset
/// AirDrop settings back to the desired value after a delay.
class PrefWatcher {
    
    /// Reports updates to UI/menu via delegate
    var delegate: DataModelDelegate?
    /// Whether we can post local notifications
    var notificationsAllow = false
    /// (Unused) Placeholder for FSEvents stream if needed
    var eventStream: FSEventStreamRef?
    /// Dispatch source for low-level file change events
    var source: DispatchSourceFileSystemObject?
    /// Pending delayed reset, if one has been scheduled.
    var resetTask: Task<Void, Never>?
    /// Backed UserDefaults domain for sharingd
    let domain = UserDefaults(suiteName: "com.apple.sharingd")
    /// Full path to com.apple.sharingd.plist under the current user's Library/Preferences
    var filePath = ""
    
    // MARK: - Monitoring
    /// Starts monitoring the preferences file for rename/delete, which indicates a write.
    /// Re-establishes the watch as needed when the file is rotated.
    func startMonitoring() {
        if source != nil {
            return
        }

        do {
            // Open an event-only file descriptor to observe changes
            let fdesc = try FileDescriptor.open(filePath, .readOnly, options: .eventOnly)
            
            // Create a DispatchSource for all file system events on the descriptor
            let newSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fdesc.rawValue, eventMask: .all, queue: .global())
            source = newSource
            newSource.setEventHandler { [weak self] in
                guard let self else { return }
                let event = newSource.data
                
                Logger.airdropstatus.info("\(self.filePath) File system event: \(newSource.dataStrings.joined(separator: ", "))")
                
                // File was rotated/replaced, treat as a write and reconfigure monitoring
                if event.contains(.delete) || event.contains(.rename) {
                    self.stopMonitoring()
                    
                    // Notify delegate with the new AirDrop status
                    if let ADstatus = self.domain?.string(forKey: "DiscoverableMode") {
                        DispatchQueue.main.async {
                            self.delegate?.didReceiveDataUpdate(airDropStatus: ADstatus)
                        }
                        Logger.airdropstatus.info("Airdrop Status Changed to \(ADstatus)")
                    }
                    
                    // Schedule enforcement back to the desired setting
                    Task {
                        await self.resetAirDrop()
                    }
                    
                    self.startMonitoring()
                }
            }
            
            newSource.setCancelHandler {
                do {
                    try fdesc.close()
                } catch {
                    Logger.airdropstatus.error("\(error.localizedDescription)")
                }
            }
            
            newSource.resume()
            
        } catch {
            Logger.airdropstatus.error("\(error.localizedDescription)")
        }
    }
    
    // MARK: - Enforcement
    /// Waits the configured delay and then calls resetDiscoverableMode() unless
    /// the system is already at the desired state or Off.
    func resetAirDrop() async {
        // No enforcement needed if already compliant or Off
        if domain!.string(forKey: "DiscoverableMode") == UserDefaults.standard.string(forKey: "airDropSetting") || domain!.string(forKey: "DiscoverableMode") == "Off" {
            resetTask?.cancel()
            resetTask = nil
            return
            
        } else {
            // Read the enforcement delay (in minutes) from UserDefaults
            let ADATimer = UserDefaults.standard.integer(forKey: "timing")
            let fullTime = Double(ADATimer * 60)
            Logger.airdropstatus.info("ADA will change AirDrop Setting in \(fullTime) seconds to \(UserDefaults.standard.string(forKey: "airDropSetting") ?? "")")
            Logger.airdropstatus.info("ADA Timer Started")
            let clock = ContinuousClock()
            let now = clock.now
            let futureTime = now.advanced(by: .seconds(fullTime))
            let tolerance: Duration = .seconds(0.5)
            
            // Sleep until the desired time using ContinuousClock, then enforce
            resetTask?.cancel()
            resetTask = Task { [weak self] in
                do {
                    try await Task.sleep(until: futureTime, tolerance: tolerance, clock: clock)
                    guard !Task.isCancelled else { return }
                    guard let self else { return }
                    if self.domain!.string(forKey: "DiscoverableMode") == UserDefaults.standard.string(forKey: "airDropSetting") || self.domain!.string(forKey: "DiscoverableMode") == "Off" {
                        self.resetTask = nil
                        return
                    }
                    self.resetDiscoverableMode()
                } catch {
                    return
                }
            }
        }
    }
    
    func stopMonitoring() {
        source?.cancel()
        source = nil
    }
    /// Immediately enforce the desired DiscoverableMode, wait for AirDrop activity to finish,
    /// restart sharingd to apply, optionally post a notification, and re-arm monitoring.
    func resetDiscoverableMode() {
        guard let ADASetting = UserDefaults.standard.string(forKey: "airDropSetting") else { return }
        resetTask = nil
        stopMonitoring()
        // Pause monitoring while we mutate the file
        let nc = UNUserNotificationCenter.current()
        let domain = UserDefaults(suiteName: "com.apple.sharingd")
        // Set the desired AirDrop mode
        domain?.set(ADASetting, forKey: "DiscoverableMode")
        Logger.airdropstatus.info("Airdrop Status changed by ADA to \(ADASetting)")
        var airDropInUse = true
        repeat {
            let task = Process()
            task.launchPath = "/bin/bash"
            // Poll for active AirDrop file activity to avoid interrupting transfers
            let command = """
        /usr/sbin/lsof -c sharingd | /usr/bin/awk '$5 == "REG" && $4 ~ /[rw]/ && $0 !~ /Group Containers|AirDropHashDB/'
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
        // Restart sharingd to ensure the new setting takes effect
        let process = Process()
        process.launchPath = "/usr/bin/killall"
        process.arguments = ["sharingd"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        process.launch()
        process.waitUntilExit()
        // Post a local notification to inform the user of the change
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
                let notificationID = "airdrop-status-changed"
                nc.removePendingNotificationRequests(withIdentifiers: [notificationID])
                nc.removeDeliveredNotifications(withIdentifiers: [notificationID])

                let request = UNNotificationRequest(
                    identifier: notificationID,
                    content: content,
                    trigger: trigger
                )
                try await nc.add(request)
            }
        }
        // Resume watching after enforcement
        self.startMonitoring()
        
        
    }
}
