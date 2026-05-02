//
//  AirDropLogging.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 3/29/26.
//

import Foundation
import RegexBuilder
import OSLog

// MARK: - AirDropLogging Overview
// Streams and parses sharingd AirDrop logs into summarized JSON lines.

/// AirDropLogging
///
/// Streams `sharingd` logs via `/usr/bin/log stream` with a predicate focused on AirDrop-related
/// messages, incrementally parses them with RegexBuilder, and writes summarized AirDrop events
/// as JSON lines to `~/Library/Logs/ADA.json`.
///
/// The parser supports both incoming and outgoing transfers and captures:
/// - Direction (incoming/outgoing)
/// - Transfer ID
/// - Status (completedSuccessfully / Cancelled)
/// - Timestamp and elapsed time
/// - File count and file paths
/// - Peer details (sender/receiver IDs, names, devices)

/// A codable representation of a summarized AirDrop event written to the log file.
/// Note: Not every field is present for every direction. Optional peer details
/// are populated when available from the parsed logs.
struct AirDropEvent: Codable {
    let direction: String          // "incoming" or "outgoing"
    let transferID: String         // Unique transfer identifier observed in logs
    let status: String             // e.g., "completedSuccessfully" or "Cancelled"
    let timestamp: String          // Log timestamp when we first observed the transfer
    let time: String               // Elapsed time reported by sharingd for the transfer
    let fileCount: String          // Number of files involved in the transfer (string as parsed)
    let files: [String]            // Decoded file paths for items in the transfer

    // Outgoing-only peer details (destination)
    let receiverID: String?
    let receiverName: String?
    let receiverDevice: String?

    // Incoming-only peer details (source)
    let senderDeviceID: String?
    let senderName: String?
    let senderDevice: String?
}

/// Streams sharingd logs and emits summarized AirDrop transfer events.
class SharingdLogStreamer {
    /// Backing process for /usr/bin/log stream
    private let process = Process()
    // Pipe to capture both stdout and stderr of `log stream`
    private let pipe = Pipe()
    
    /// Start streaming and parsing; throws if the log process cannot be launched.
    func start() throws {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        
        // Predicate to target AirDrop-related messages from sharingd
        let predicate = """
            process == "sharingd" AND \
            subsystem == "com.apple.sharing" AND \
            (category == "AirDropNW" OR category == "AirDropNWClient" OR category BEGINSWITH "AirDrop.") AND \
            ( eventMessage CONTAINS "ASK request ID" OR \
              eventMessage CONTAINS "Importing END" OR \
              eventMessage CONTAINS "Issued sandbox token for url" OR \
              eventMessage CONTAINS "completed(file://" OR \
              eventMessage CONTAINS "state: .completedSuccessfully(" OR \
              eventMessage CONTAINS "Send StateMachine START" OR \
              eventMessage CONTAINS "Received ASK response {response: ASK response" OR \
              eventMessage CONTAINS "Adding file items (count=" ) OR \
              eventMessage CONTAINS " was cancelled."
            """
        
        // Use JSON style for easier parsing and filter by process to reduce noise.
        process.arguments = [
            "stream",
            "--style", "json",
            "--process", "sharingd",
            "--predicate", predicate
            
        ]
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Accumulated state across related log lines
        var transferID: String = ""
        var receiverName: String = ""
        var sendStateMessage = ""
        var airDropLogDict = [String: Any]()
        var fileArray: [String] = []
        
        // Incrementally parse each JSON log line as it arrives
        pipe.fileHandleForReading.readabilityHandler = { logstream in
            let data = logstream.availableData
            
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self).dropFirst()
            guard let newTextData = String(text).data(using: .utf8) else {
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: newTextData) as? [String: Any],
                  let timestamp  = json["timestamp"]  as? String,
                  let message    = json["eventMessage"] as? String
            else {
                return
            }
            
            // Begin parsing known message shapes. We gate by substrings to avoid expensive
            // regex work on unrelated messages.
            
            // Incoming transfer announcement
            if message.contains("Message id: "){
                // Incoming transfer announcement with sender metadata and initial counts.
                
                airDropLogDict = ["direction": "incoming"]
                airDropLogDict["timestamp"] = timestamp
                
                // Sender display name: Nm "<name>"
                var regex = /Nm\s+"([^"]+)"/
                if let match = message.firstMatch(of: regex) {
                    let senderName = String(match.1)
                    airDropLogDict["senderName"] = senderName
                }
                
                // Sender device model: Md <model>,
                regex = /Md\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let senderDevice = String(match.1)
                    airDropLogDict["senderDevice"] = senderDevice
                }
                
                // Sender device ID: Sender <id>,
                regex = /Sender\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let senderDeviceID = String(match.1)
                    airDropLogDict["senderDeviceID"] = senderDeviceID
                }
                
                // Transfer ID: transferID: <id>),
                regex = /transferID:\s+([^,]+)\),/
                if let match = message.firstMatch(of: regex) {
                    transferID = String(match.1)
                    airDropLogDict["transferID"] = transferID
                }
                
                // File count: files.count: <n>,
                regex = /files.count:\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let filesCount = String(match.1)
                    airDropLogDict["fileCount"] = filesCount
                }
                
            }
            // Incoming cancellation
            if message.contains("was cancelled.") {
                let regex = /Transfer ([A-F0-9]+)/
                if let match = message.firstMatch(of: regex) {
                    let canceledTransferID = String(match.1)
                    if canceledTransferID == transferID {
                        airDropLogDict["status"] = "Cancelled"
                        airDropLogDict["files"] = fileArray
                        fileArray.removeAll()
                        
//                        print(airDropLogDict)
                        do {
                            try self.writeLogs(log: airDropLogDict)
                            Logger.airdroplogger.info("AirDrop log wrote")
                        } catch {
                            Logger.airdroplogger.error("Failed to write AirDrop log")
                        }
                        
                    }
                    
                }
            }
            // Sandbox-issued file URL
            if message.contains("Issued sandbox token for url") {
                let regex = /url+\s(.*)/
                if let match = message.firstMatch(of: regex) {
                    let filePath = String(match.1)
                    if let url = URL(string: String(filePath)) {
                        if let decodedPath = url.path().removingPercentEncoding {
                            fileArray.append(decodedPath)
                        }
                    }
                }
                
            }
            
            // Incoming completion
            if message.contains("Receive transfers updates in daemon") {
                var regex = /\[([^:]+):/
                if let match = message.firstMatch(of: regex) {
                    let receiveTransferID = String(match.0).dropFirst().dropLast()
                    
                    if receiveTransferID == transferID {
                        
                        regex = /time:\s+([^,]+)}/
                        if let match = message.firstMatch(of: regex) {
                            let timeItTook = String(match.1)
                            airDropLogDict["time"] = timeItTook
                            airDropLogDict["status"] = "completedSuccessfully"
                            airDropLogDict["files"] = fileArray
                            fileArray.removeAll()
                            //                        print(airDropLogDict)
                                                    do {
                                                        try self.writeLogs(log: airDropLogDict)
                                                        Logger.airdroplogger.info("AirDrop log wrote")
                                                    } catch {
                                                        Logger.airdroplogger.error("Failed to write AirDrop log")
                                                    }

                        }
                    }
                }
            }
            
            // Outgoing start
            if message.contains("Send StateMachine START") {
                airDropLogDict = ["direction": "outgoing"]
                airDropLogDict["timestamp"] = timestamp
                let regex = /T+\s(.*.)\s+{/
                if let match = message.firstMatch(of: regex) {
                    transferID = String(match.1)
                    airDropLogDict["transferID"] = transferID
                }
                sendStateMessage = message
                
            }
            
            // Outgoing ASK response
            if message.contains("Received ASK response") {
                
                let regex = /Nm\s+"([^"]+)"/
                if let match = message.firstMatch(of: regex) {
                    receiverName = String(match.1)
                    airDropLogDict["receiverName"] = receiverName
                    
                    // Build a regex to capture the receiver device UUID following the name.
                    var builtRegex = Regex {
                        "Nm "
                        receiverName
                        OneOrMore(.whitespace)
                        "Md "
                        OneOrMore(.any.subtracting(.whitespace))
                        OneOrMore(.whitespace)
                        "ID "
                        Capture {
                            // UUID format
                            Repeat(.hexDigit, count: 8)
                            "-"
                            Repeat(.hexDigit, count: 4)
                            "-"
                            Repeat(.hexDigit, count: 4)
                            "-"
                            Repeat(.hexDigit, count: 4)
                            "-"
                            Repeat(.hexDigit, count: 12)
                        }
                    }
                    
                    let receiverID = sendStateMessage.firstMatch(of: builtRegex)?.output.1.map(String.init).joined()
                    airDropLogDict["receiverID"] = receiverID
                    
                    // Build a regex to capture the receiver device model (Md ...).
                    builtRegex = Regex {
                        "Nm "
                        receiverName
                        OneOrMore(.whitespace)
                        "Md "
                        Capture {
                            OneOrMore(.any.subtracting(.whitespace))
                        }
                        OneOrMore(.whitespace)
                        "ID "
                    }
                    let receiverDevice = sendStateMessage.firstMatch(of: builtRegex)?.output.1.map(String.init).joined()
                    
                    airDropLogDict["receiverDevice"] = receiverDevice
                }
                
            }
            
            // Outgoing device ID fallback
            if let name = airDropLogDict["receiverName"] as? String {
                
                if message.contains("Nm \(name) Md nil ID ") {
                    let regex = /ID (.*?) CID/
                    if let match = message.firstMatch(of: regex) {
                        let deviceID = String(match.1)
                        airDropLogDict["receiverDeviceID"] = deviceID
                    }
                }
            }
            // Outgoing file items
            if message.contains("Adding file items") {
                var regex = /\(count=([0-9])+\)/
                if let match = message.firstMatch(of: regex) {
                    let fileCount = String(match.1)
                    airDropLogDict["fileCount"] = fileCount
                    
                    
                }
                regex = /\[([^\]]+)\]/
                if let match = message.firstMatch(of: regex) {
                    let fileList = String(match.1)
                    let files = fileList.split(separator: ", ")
                    var fileArray: [String] = []
                    for file in files {
                        if let url = URL(string: String(file)) {
                            if let decodedPath = url.path().removingPercentEncoding {
                                fileArray.append(decodedPath)
                            }
                            
                        }
                    }
                    airDropLogDict["files"] = fileArray
                }
                
            }
            
            // Outgoing completion
            if message.contains("SDAirDropSendService.transfers") && message.contains("completedSuccessfully"){
                var regex = /id:\s+([^:]+),/
                if let match = message.firstMatch(of: regex) {
                    let receiveTransferID = String(match.1)
                    if receiveTransferID == transferID {
                        regex = /time:\s(.*?)}/
                        if let match = message.firstMatch(of: regex) {
                            let timeItTook = String(match.1)
                            airDropLogDict["time"] = timeItTook
                            airDropLogDict["status"] = "completedSuccessfully"
                            //                        print(airDropLogDict)
                                                    do {
                                                        try self.writeLogs(log: airDropLogDict)
                                                        Logger.airdroplogger.info("AirDrop log wrote")
                                                    } catch {
                                                        Logger.airdroplogger.error("Failed to write AirDrop log")
                                                    }

                        }
                    }
                }
            }
            
            // Outgoing cancellation
            if message.contains("Canceling send transfer") {
                let regex = /transfer ([A-F0-9]+)/
                if let match = message.firstMatch(of: regex) {
                    let canceledTransferID = String(match.1)
                    if canceledTransferID == transferID {
                        airDropLogDict["status"] = "Cancelled"
                        //                        print(airDropLogDict)
                                                do {
                                                    try self.writeLogs(log: airDropLogDict)
                                                    Logger.airdroplogger.info("AirDrop log wrote")
                                                } catch {
                                                    Logger.airdroplogger.error("Failed to write AirDrop log")
                                                }

                    }
                    
                }
            }
            
        }
        // Start streaming after the handler is set to avoid losing early lines.
        Logger.airdroplogger.info("AirDrop Logging started")
        try process.run()
    }
    
    /// Stop streaming and tear down process.
    func stop() {
        process.terminate()
        Logger.airdroplogger.info("AirDrop Logging stopped")
    }
    
    /// Returns whether the underlying log process is running.
    func checkStatus() -> Bool {
        return process.isRunning
    }
    
    /// Inspect managed logging prefs to see if private data is enabled for com.apple.sharing.
    func checkProfileStatus() -> Bool {
        let domain = "com.apple.system.logging"
        let bundle_plist = UserDefaults.init(suiteName: domain)
        // Inspect the managed preferences domain to see if Subsystems -> com.apple.sharing -> DEFAULT-OPTIONS -> Enable-Private-Data == 1
        if CFPreferencesAppValueIsForced("Subsystems" as CFString, domain as CFString) {
            if let preference_value = bundle_plist?.value(forKey: "Subsystems"), let sharing_subsystem = preference_value as? [String: AnyObject], let sharing_subsystem_value = sharing_subsystem["com.apple.sharing"] as? [String: AnyObject], let enable_private_data = sharing_subsystem_value["DEFAULT-OPTIONS"] as? [String: Int], let enable_private_data_value = enable_private_data["Enable-Private-Data"] {
                if enable_private_data_value == 1 {
                    return true
                }
            }
        }

        return false
    }
    
    /// Append one event to ADA.json in the user's Library/Logs.
    func writeLogs(log: [String: Any]) throws -> Void{
        // Persist to the user's Library/Logs as ADA.json (JSON Lines format).
        let logURL = URL.libraryDirectory.appending(components: "Logs", "ADA.json")

        // Use JSONSerialization since the input is a heterogenous [String: Any] dictionary.
        let data = try JSONSerialization.data(withJSONObject: log)

        guard var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"

        // Append if the file exists; otherwise create a new file atomically.
        if FileManager.default.fileExists(atPath: logURL.path) {
            let handle = try FileHandle(forWritingTo: logURL)
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            try handle.close()
        } else {
            try line.data(using: .utf8)?.write(to: logURL, options: .atomic)
        }
    }
}

