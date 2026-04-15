//
//  AirDropLogging.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 3/29/26.
//

import Foundation


struct LogEvent: Decodable {
    let timestamp: String
    let subsystem: String?
    let category: String?
    let eventMessage: String
    let processImagePath: String?
}

class SharingdLogStreamer {
    private let process = Process()
    private let pipe = Pipe()

    func start() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")

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
//        let predicate = """
//                subsystem == "com.apple.sharing" AND \
//                (category == "AirDropNW" OR category BEGINSWITH "AirDrop.") AND \
//                (eventMessage CONTAINS "ASK request ID" OR \
//                eventMessage CONTAINS "Importing END" OR \
//                eventMessage CONTAINS "completedSuccessfully" OR \
//                eventMessage CONTAINS "Issued sandbox token for url" OR \
//                eventMessage CONTAINS "transferring(progress: completed(file://") OR \
//                eventMessage CONTAINS "Send StateMachine START" OR \
//                eventMessage CONTAINS "Resolved endpoints to [Application Service <" OR \
//                eventMessage CONTAINS "Received ASK response {response: ASK response" OR \
//                eventMessage CONTAINS "Adding file items (count=" OR \
//                eventMessage CONTAINS "Sending UPLOAD request [" OR 
//                """
//        eventMessage CONTAINS "state: .completedSuccessfully("
        process.arguments = [
            "stream",
            "--style", "json",
            "--process", "sharingd",
            "--predicate", predicate
           
        ]
        process.standardOutput = pipe
        process.standardError = pipe
        var transferID: String = ""
        pipe.fileHandleForReading.readabilityHandler = { logstream in
            let data = logstream.availableData
            
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self).dropFirst()
            guard let newTextData = String(text).data(using: .utf8) else {
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: newTextData) as? [String: Any],
            let timestamp  = json["timestamp"]  as? String,
//                          let subsystem  = json["subsystem"]  as? String,
                          let category   = json["category"]   as? String,
                          let message    = json["eventMessage"] as? String
            else {
                return
            }
//            print("******\(message)******")
//            //receiving
            
//            if message.contains("Sender ") {
            if message.contains("Message id: "){
                print("RECEIVING")
//                do {
                    print(timestamp)
                    var regex = /Nm\s+"([^"]+)"/

                    if let match = message.firstMatch(of: regex) {
                        let senderName = String(match.1)
                        print(senderName)
                    }
                
                regex = /Md\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let senderDevice = String(match.1)
                    print(senderDevice)
                }
                
                regex = /transferID:\s+([^,]+)\),/
                if let match = message.firstMatch(of: regex) {
                    transferID = String(match.1)
                    print(transferID)
                }
                regex = /files.count:\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let filesCount = String(match.1)
                    print(filesCount)
                }
               
                regex = /Sender\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let senderDeviceID = String(match.1)
                    print(senderDeviceID)
                }
                
            }
            if message.contains("was cancelled.") {
                let regex = /Transfer ([A-F0-9]+)/
                if let match = message.firstMatch(of: regex) {
                    let canceledTransferID = String(match.1)
                    if canceledTransferID == transferID {
                        print("\(transferID) Canceled")
                    }
                    
                }
            }
            
            if category == "AirDrop.\(transferID)" {
                
                let regex = /\[.*?\]/
                if let match = message.firstMatch(of: regex) {
                    let fileList = String(match.0)
                    
                    let files = fileList.split(separator: ", ")
                    for file in files {
                        if let url = URL(string: String(file)) {
                            print(url.path())
                        }
                    }
                }
            }
        
            if message.contains("Receive transfers updates in daemon") {
//                print("receive transfers updates in daemon")
//                print(message)
//                //state: .completedSuccessfully({time: 12sec})
//                //startDate: 2026-03-31 20:16:03 +0000,
                
//                    let timeStamp = try Regex("(?<=startDate: ).*?(?=, )").firstMatch(in: message)
                    var regex = /\[([^:]+):/
                    if let match = message.firstMatch(of: regex) {
                        let receiveTransferID = String(match.0).dropFirst().dropLast()
                        
                        if receiveTransferID == transferID {
//                            regex = /startDate:\s+([^,]+),/
//                            if let match = message.firstMatch(of: regex) {
//                                let timeStamp = String(match.1)
//                                print(timeStamp)
//                            }
                            regex = /time:\s+([^,]+)}/
                            if let match = message.firstMatch(of: regex) {
                                let timeItTook = String(match.1)
                                print(timeItTook)
                                print("Completed")
                            }
                        }
                    }

                    
                    
                
               
            }
            //sending
            
            if message.contains("Send StateMachine START") {
                print("SENDING")
                var regex = /T+\s(.*.)\s+{/
                if let match = message.firstMatch(of: regex) {
                    transferID = String(match.1)
                    print(transferID)
                }
                
                 regex = /Nm\s+"([^"]+)"/

                if let match = message.firstMatch(of: regex) {
                    let receiverName = String(match.1)
                    print(receiverName)
                }
            
                regex = /Md\s+([^,]+),/
                if let match = message.firstMatch(of: regex) {
                    let receiverDevice = String(match.1)
                    print(receiverDevice)
                }
                
                regex = /ID\s+([^,]+)\s+CID/
                if let match = message.firstMatch(of: regex) {
                    let deviceID = String(match.1)
                    print(deviceID)
                }
                
            }
            if message.contains("Adding file items") {
                var regex = /\(count=([0-9])+\)/
                if let match = message.firstMatch(of: regex) {
                    let fileCount = String(match.1)
                    print("file count: \(fileCount)")
                }
                regex = /\[([^\]]+)\]/
                if let match = message.firstMatch(of: regex) {
                    let fileList = String(match.1)
                    let files = fileList.split(separator: ", ")
                    for file in files {
                        if let url = URL(string: String(file)) {
                            print(url.path())
                        }
                    }
                }
                
            }
            
            if message.contains("SDAirDropSendService.transfers") && message.contains("completedSuccessfully"){                
                var regex = /id:\s+([^:]+),/
                
                if let match = message.firstMatch(of: regex) {
                    let receiveTransferID = String(match.1)
                    print(receiveTransferID)
                    if receiveTransferID == transferID {
                        regex = /time:\s(.*?)}/
                        if let match = message.firstMatch(of: regex) {
                            let timeItTook = String(match.1)
                            print(timeItTook)
                            print("Completed")
                        }
                    }
                }
            }

        }

        try process.run()
    }

}
