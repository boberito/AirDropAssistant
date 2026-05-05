//
//  PreferencesWindow.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/17/24.
//

import Cocoa

// MARK: - PreferencesWindow Overview
/// Minimal NSWindow subclass that hides instead of destroying when closed.
class PreferencesWindow: NSWindow {
    /// Override close to order out (hide) the window instead of fully closing it.
    override func close() {
        // Keep window instance alive; just remove from screen
        self.orderOut(NSApp)
    }
}
