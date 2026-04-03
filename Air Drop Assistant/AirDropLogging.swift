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

final class SharingdLogStreamer {
    private let process = Process()
    private let pipe = Pipe()

    func start() throws {
        print("log starting?")
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
              eventMessage CONTAINS "Adding file items (count=" )
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
//                          let category   = json["category"]   as? String,
                          let message    = json["eventMessage"] as? String
            else {
                return
            }
//            print("******\(message)******")
//            //receiving
//            if message.contains("Sender") {
//                print("SENDER")
//                print(message)
//                //get Nm "sender name"
//                //get Md "sender device"
//                //get files count
//                //
//            }
//            if message.contains("importedURLs") {
//                print("importedURLs")
//                print(message)
//                
//                //importedURLs - file sent
//                
//            }
//            if message.contains("Receive transfers updates in daemon") {
//                print("receive transfers updates in daemon")
//                print(message)
//                //state: .completedSuccessfully({time: 12sec})
//                //startDate: 2026-03-31 20:16:03 +0000,
//                
//            }
            //sending
            if message.contains("Adding file items") {
//                Adding file items (count=2) to request: [file:///var/folders/ds/kv3wyvln7kd0bpdz182np45c0000gn/T/TemporaryItems/NSIRD_Finder_2AVmOx/IMG_0581.PNG, file:///var/folders/ds/kv3wyvln7kd0bpdz182np45c0000gn/T/TemporaryItems/NSIRD_Finder_8DGQux/IMG_0581%202.PNG]

                
                
                print("Adding file items")
                let files = message.split(separator: ": ")[1].split(separator: ", ")
                print(files)
                //file count
                //file name
            }
//            if message.contains("Received ASK response") {
//                print("Recived ASK response")
//                print(message)
//                //Nm "device nmae"
//                //Md "device type"
//                print(timestamp)
//                //start time
//                
//            }
//            if message.contains("SDAirDropSendService.transfers") {
//                print("SD AirDrop Send Service Transfers")
//                print(message)
//                //.completedSuccessfully(metrics: {C11A1F5C, time: 14sec}
//            }
            
            
        }

        try process.run()
    }

}
