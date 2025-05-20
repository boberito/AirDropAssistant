//
//  Logger.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 5/19/25.
//

import Foundation
import OSLog
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let airdropstatus = Logger(subsystem: subsystem, category: "airdrop_status")
    static let updater = Logger(subsystem: subsystem, category: "updater")
    static let general = Logger(subsystem: subsystem, category: "general")
}
