//
//  Logger.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 5/19/25.
//

import Foundation
import OSLog

// MARK: - Logger Overview
// Centralized OSLog categories for the app. Use these static properties for structured logging.

/// Convenience categories bound to the app's bundle identifier.
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!
    /// Logs AirDrop status changes and enforcement activity
    static let airdropstatus = Logger(subsystem: subsystem, category: "airdrop_status")
    /// Logs update check flow and results
    static let updater = Logger(subsystem: subsystem, category: "updater")
    /// Logs general app lifecycle and user actions
    static let general = Logger(subsystem: subsystem, category: "general")
    
    static let airdroplogger = Logger(subsystem: subsystem, category: "airdrop_logging")
}
