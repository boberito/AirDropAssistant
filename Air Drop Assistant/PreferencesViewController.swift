//
//  PreferencesViewController.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/17/24.
//


import Cocoa
import ServiceManagement

protocol PrefDataModelDelegate {
    func didRecievePrefUpdate(iconMode: String)
    func checkAirDrop()
}

class PreferencesViewController: NSViewController {
    
    var delegate: PrefDataModelDelegate?
    override func viewDidDisappear() {
        delegate?.checkAirDrop()
    }
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
        
        let iconLabel = NSTextField(frame: NSRect(x: 200, y: 110, width: 150, height: 25))
        iconLabel.stringValue = "Select Menu Icon"
        iconLabel.isBordered = false
        iconLabel.isBezeled = false
        iconLabel.isEditable = false
        iconLabel.drawsBackground = false
        
        let colorfulIcon = NSImageView(frame:NSRect(x: 205, y:86, width: 50, height: 40))
        let coloricon = NSImage(named: NSImage.Name("menuicon"))
        coloricon?.size.width = 18
        coloricon?.size.height = 18
        colorfulIcon.image = coloricon
        
        
        let monochromeIcon = NSImageView(frame:NSRect(x: 205, y:62, width: 50, height: 40))
        
        
        let monoicon = NSImage(named: NSImage.Name("menuicon_mono"))
        monoicon?.size.width = 18
        monoicon?.size.height = 18
        monochromeIcon.image = monoicon
        
        
        let iconOneRadioButton = NSButton(radioButtonWithTitle: "", target: Any?.self, action: #selector(changeIcon))
        iconOneRadioButton.frame = NSRect(x: 200, y: 95, width: 150, height: 25)
        //        iconOneRadioButton.title = "Colorful"
        iconOneRadioButton.title = "     Colorful"
        
        let iconTwoRadioButton = NSButton(radioButtonWithTitle: "", target: Any?.self, action: #selector(changeIcon))
        iconTwoRadioButton.frame = NSRect(x: 200, y: 70, width: 150, height: 25)
        //        iconTwoRadioButton.title = "Monochrome"
        iconTwoRadioButton.title = "     Monochrome"
        if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
            iconTwoRadioButton.state = .on
            iconOneRadioButton.state = .off
        } else {
            iconOneRadioButton.state = .on
            iconTwoRadioButton.state = .off
        }
        
        
        let infoTextView = NSTextField(frame: NSRect(x: 183, y: -40, width: 300, height: 100))
        
        infoTextView.font = NSFont.systemFont(ofSize: 18)
        infoTextView.isBordered = false
        infoTextView.isBezeled = false
        infoTextView.isEditable = false
        infoTextView.drawsBackground = false
        
        if let versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let infoString = """
    Air Drop Assistant
    Version: \(versionText)
"""
            infoTextView.stringValue = infoString
        }
        
        let startUpButton = NSButton(checkboxWithTitle: "Launch at Login", target: Any?.self, action: #selector(loginItemChange))
        startUpButton.frame = NSRect(x: 20, y: 115, width: 200, height: 25)
        let appService = SMAppService.agent(plistName: "com.ttinc.Air-Drop-Assistant.plist")
        switch appService.status {
        case .enabled:
            startUpButton.intValue = 1
            
        case .notFound:
            startUpButton.intValue = 0
            
        case .notRegistered:
            startUpButton.intValue = 0
            
        case .requiresApproval:
            startUpButton.intValue = 0
            
        default:
            startUpButton.intValue = 0
        }
        
        let appIcon = NSImageView(frame:NSRect(x: 40, y:10, width: 100, height: 100))
        appIcon.image = NSImage(named: "AppIcon")
        
        view.addSubview(iconLabel)
        view.addSubview(colorfulIcon)
        view.addSubview(monochromeIcon)
        view.addSubview(iconOneRadioButton)
        view.addSubview(iconTwoRadioButton)
        view.addSubview(appIcon)
        view.addSubview(infoTextView)
        //        view.addSubview(updateButton)
        view.addSubview(startUpButton)
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
    
    @objc func changeIcon(_ sender: NSButton) {
        //use UserDefaults
        
        if sender.title == "     Monochrome" {
            UserDefaults.standard.set("bw", forKey: "icon_mode")
            
            self.delegate?.didRecievePrefUpdate(iconMode: "bw")
        }
        
        if sender.title == "     Colorful" {
            UserDefaults.standard.set("colorful", forKey: "icon_mode")
            self.delegate?.didRecievePrefUpdate(iconMode: "colorful")
            
        }
    }
    
    @objc func loginItemChange(_ sender: NSButton) {
        let appService = SMAppService.agent(plistName: "com.ttinc.Air-Drop-Assistant.plist")
        
        if sender.intValue == 1 {
        
            do {
                try appService.register()
                NSLog("registered service")
            } catch {
                NSLog("problem registering service")
            }
        } else {
            do {
                if appService.status == .enabled {
                    try appService.unregister()
                
                    NSLog("unregistered service")
                }
                
            } catch {
                
                NSLog("problem unregistering service")
            }
        }
    }
    
}
