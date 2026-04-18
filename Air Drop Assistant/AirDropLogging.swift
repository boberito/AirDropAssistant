//
//  AirDropLogging.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 3/29/26.
//

import Foundation
import RegexBuilder
import OSLog

struct AirDropEvent: Codable {
    let direction: String
    let transferID: String
    let status: String
    let timestamp: String
    let time: String
    let fileCount: String
    let files: [String]

    // Outgoing
    let receiverID: String?
    let receiverName: String?
    let receiverDevice: String?

    // Incoming
    let senderDeviceID: String?
    let senderName: String?
    let senderDevice: String?
}

class SharingdLogStreamer {
    private let process = Process()
    private let pipe = Pipe()
    
    func start() throws {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
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
        
        process.arguments = [
            "stream",
            "--style", "json",
            "--process", "sharingd",
            "--predicate", predicate
            
        ]
        process.standardOutput = pipe
        process.standardError = pipe
        var transferID: String = ""
        var receiverName: String = ""
        var sendStateMessage = ""
        var airDropLogDict = [String: Any]()
        var fileArray: [String] = []
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
            if message.contains("Message id: "){
                
                airDropLogDict = ["direction": "incoming"]
                airDropLogDict["timestamp"] = timestamp
                
                var regex = /Nm\s+"([^"]+)"/
                
                if let match = message.firstMatch(of: regex) {
                    let senderName = String(match.1)
                    airDropLogDict["senderName"] = senderName
                }
                
                regex = /Md\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let senderDevice = String(match.1)
                    airDropLogDict["senderDevice"] = senderDevice
                }
                regex = /Sender\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let senderDeviceID = String(match.1)
                    airDropLogDict["senderDeviceID"] = senderDeviceID
                }
                regex = /transferID:\s+([^,]+)\),/
                if let match = message.firstMatch(of: regex) {
                    transferID = String(match.1)
                    airDropLogDict["transferID"] = transferID
                }
                regex = /files.count:\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let filesCount = String(match.1)
                    airDropLogDict["fileCount"] = filesCount
                }
                
            }
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
            
            if message.contains("Received ASK response") {
                
                let regex = /Nm\s+"([^"]+)"/
                if let match = message.firstMatch(of: regex) {
                    receiverName = String(match.1)
                    airDropLogDict["receiverName"] = receiverName
                    
                    
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
            
            if let name = airDropLogDict["receiverName"] as? String {
                
                if message.contains("Nm \(name) Md nil ID ") {
                    let regex = /ID (.*?) CID/
                    if let match = message.firstMatch(of: regex) {
                        let deviceID = String(match.1)
                        airDropLogDict["receiverDeviceID"] = deviceID
                    }
                }
            }
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
        Logger.airdroplogger.info("AirDrop Logging started")
        try process.run()
    }
    func stop() {
        process.terminate()
        Logger.airdroplogger.info("AirDrop Logging stopped")
    }
    
    func checkStatus() -> Bool {
        return process.isRunning
    }
    
    func checkProfileStatus() -> Bool {
        let domain = "com.apple.system.logging"
        let bundle_plist = UserDefaults.init(suiteName: domain)
        if CFPreferencesAppValueIsForced("Subsystems" as CFString, domain as CFString) {
            if let preference_value = bundle_plist?.value(forKey: "Subsystems"), let sharing_subsystem = preference_value as? [String: AnyObject], let sharing_subsystem_value = sharing_subsystem["com.apple.sharing"] as? [String: AnyObject], let enable_private_data = sharing_subsystem_value["DEFAULT-OPTIONS"] as? [String: Int], let enable_private_data_value = enable_private_data["Enable-Private-Data"] {
                if enable_private_data_value == 1 {
                    return true
                }
            }
        }

        return false
    }
    
    func writeLogs(log: [String: Any]) throws -> Void{
        let logURL = URL.libraryDirectory.appending(components: "Logs", "ADA.json")

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
        let data = try JSONSerialization.data(withJSONObject: log)

            guard var line = String(data: data, encoding: .utf8) else { return }
            line += "\n"

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
