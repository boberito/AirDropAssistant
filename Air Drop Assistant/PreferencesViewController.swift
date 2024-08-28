//
//  PreferencesViewController.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/17/24.
//


import Cocoa

class PreferencesViewController: NSViewController {
    
    override func loadView() {
        let rect = NSRect(x: 0, y: 0, width: 415, height: 200)
        view = NSView(frame: rect)
        view.wantsLayer = true
        let timelengthButton = NSPopUpButton(frame: NSRect(x: 20, y: 140, width: 150, height: 25), pullsDown: false)
        let prefTime = UserDefaults.standard.integer(forKey: "timing")
        guard let appBundleID = Bundle.main.bundleIdentifier else { return }
        if CFPreferencesAppValueIsForced("timing" as CFString, appBundleID as CFString) {
            timelengthButton.isEnabled = false
        }
        timelengthButton.addItem(withTitle: "1 Minute")
        timelengthButton.addItem(withTitle: "5 Minutes")
        timelengthButton.addItem(withTitle: "10 Minutes")
        timelengthButton.addItem(withTitle: "15 Minutes")

        if prefTime != 1 && prefTime != 5 && prefTime != 10 && prefTime != 15 {
            timelengthButton.addItem(withTitle: "\(prefTime) Minutes")
            
        }
    
        if prefTime == 1 {
            timelengthButton.selectItem(withTitle: "1 Minute")
        } else {
            timelengthButton.selectItem(withTitle: "\(prefTime) Minutes")
        }

        timelengthButton.action = #selector(timeLengthSelect)
        
        let timelengthLabel = NSTextField(frame: NSRect(x: 20, y: 160, width: 150, height: 25))
        timelengthLabel.stringValue = "Select the Time Length"
        timelengthLabel.isBordered = false
        timelengthLabel.isBezeled = false
        timelengthLabel.isEditable = false
        timelengthLabel.drawsBackground = false
        
        view.addSubview(timelengthButton)
        view.addSubview(timelengthLabel)
        
        
        let airDropSettingButton = NSPopUpButton(frame: NSRect(x: 200, y: 140, width: 150, height: 25), pullsDown: false)
        if CFPreferencesAppValueIsForced("timing" as CFString, appBundleID as CFString) {
            airDropSettingButton.isEnabled = false
        }
        airDropSettingButton.addItem(withTitle: "Off")
        airDropSettingButton.addItem(withTitle: "Contacts Only")
        airDropSettingButton.selectItem(withTitle: "Contacts Only")
        if let defaultMenuItem = UserDefaults.standard.string(forKey: "airDropSetting") {
            airDropSettingButton.selectItem(withTitle: defaultMenuItem)
        }
        airDropSettingButton.action = #selector(airDropSelect)
        
        let airDropSettingLabel = NSTextField(frame: NSRect(x: 200, y: 160, width: 200, height: 25))
        airDropSettingLabel.stringValue = "Select the Setting to Switch To"
        airDropSettingLabel.isBordered = false
        airDropSettingLabel.isBezeled = false
        airDropSettingLabel.isEditable = false
        airDropSettingLabel.drawsBackground = false
        
        let infoTextView = NSTextView(frame: NSRect(x: 175, y: 40, width: 300, height: 100))
        infoTextView.textContainerInset = NSSize(width: 10, height: 10)
        infoTextView.isEditable = false
        infoTextView.isSelectable = true
        infoTextView.drawsBackground = false
        if let versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let infoString = """
    Air Drop Assistant
    Version: \(versionText)
"""
    
            let infoAttributedString = NSMutableAttributedString(string: infoString)

        
            let normalFont = NSFont.systemFont(ofSize: 17)
            let normalRange = (infoString as NSString).range(of: infoString)
            infoAttributedString.addAttribute(.font, value: normalFont, range: normalRange)
            if UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" {
                infoAttributedString.addAttribute(.foregroundColor, value: NSColor.white, range: normalRange)  
            }
            infoTextView.textStorage?.setAttributedString(infoAttributedString)
            
        }
        let appIcon = NSImageView(frame:NSRect(x: 10, y:-25, width: 192, height: 192))
        appIcon.image = NSImage(named: "AppIcon")
        
        view.addSubview(appIcon)
        view.addSubview(infoTextView)
//        view.addSubview(updateButton)
        view.addSubview(airDropSettingButton)
        view.addSubview(airDropSettingLabel)
        
        self.view = view

    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    @objc func airDropSelect(_ popUpButton: NSPopUpButton){
        if let selected = popUpButton.titleOfSelectedItem {
            UserDefaults.standard.set(selected, forKey: "airDropSetting")
        }
        
    }
    
    
    @objc func timeLengthSelect(_ popUpButton: NSPopUpButton){
        if let selected = popUpButton.titleOfSelectedItem {
            let min = selected.split(separator: " ")[0]
            let minInt = Int(min)!
            UserDefaults.standard.set(minInt, forKey: "timing")
        }
        
    }
    
    
    
}
