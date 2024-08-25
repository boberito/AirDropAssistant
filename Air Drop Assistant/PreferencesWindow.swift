//
//  PreferencesWindow.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/17/24.
//

import Cocoa
class PreferencesWindow: NSWindow {
    override func close() {
        self.orderOut(NSApp)
    }
}
