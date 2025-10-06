//
//  PreferencesViewController.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/17/24.
//

import Cocoa
import ServiceManagement
import OSLog

// MARK: - PreferencesViewController Overview
// Implements the app's Preferences window in AppKit. Allows users to:
// - Choose default AirDrop mode
// - Select the enforcement delay (timer)
// - Toggle Launch at Login
// - Choose menu bar icon style (colorful/monochrome)
// - Configure PF-based direction restrictions via helper script

/// Delegate contract for notifying the app of preference changes that require UI or
/// functional updates (icon mode changes, AirDrop checks, PF updates).
protocol PrefDataModelDelegate {
    func didRecievePrefUpdate(iconMode: String)
    func checkAirDrop()
    func updatePF()
}

/// AppKit-based Preferences UI built programmatically without storyboards.
/// Constructs controls, wires up actions, and reflects current settings.
class PreferencesViewController: NSViewController {
    
    /// Cached PF restriction state loaded from the app's managed plist
    var pfADAPref: String?
    /// Notifies the app to react to preference changes
    var delegate: PrefDataModelDelegate?
    /// Tracks current selection index for convenience
    var currentButton: Int?
    /// Tracks previously-selected PF radio to revert on failure
    var previousRadioButton = NSButton()
    
    
    // MARK: - Lifecycle
    /// When the window closes, re-check AirDrop compliance via the delegate.
    override func viewDidDisappear() {
        NSLog("Preferences Window closed")
        delegate?.checkAirDrop()
    }
    /// Build the Preferences UI and seed all controls from UserDefaults and managed prefs.
    override func loadView() {
        // Load PF restriction state from the app's plist
        loadPref()
        let rect = NSRect(x: 0, y: 0, width: 600, height: 200)
        view = NSView(frame: rect)
        view.wantsLayer = true
        
        // Timing (delay) selector
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
        timelengthLabel.stringValue = "Select Time Length:"
        timelengthLabel.isBordered = false
        timelengthLabel.isBezeled = false
        timelengthLabel.isEditable = false
        timelengthLabel.drawsBackground = false
        
        view.addSubview(timelengthButton)
        view.addSubview(timelengthLabel)
        
        
        // Default AirDrop mode selector
        let airDropSettingButton = NSPopUpButton(frame: NSRect(x: 200, y: 140, width: 150, height: 25), pullsDown: false)
        if CFPreferencesAppValueIsForced("airDropSetting" as CFString, appBundleID as CFString) {
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
        airDropSettingLabel.stringValue = "Select Setting:"
        airDropSettingLabel.isBordered = false
        airDropSettingLabel.isBezeled = false
        airDropSettingLabel.isEditable = false
        airDropSettingLabel.drawsBackground = false
        
        // Menu bar icon style selector
        let iconLabel = NSTextField(frame: NSRect(x: 200, y: 110, width: 150, height: 25))
        iconLabel.stringValue = "Select Icon:"
        iconLabel.isBordered = false
        iconLabel.isBezeled = false
        iconLabel.isEditable = false
        iconLabel.drawsBackground = false
        
        let colorfulIcon = NSImageView(frame:NSRect(x: 205, y:80, width: 50, height: 40))
        let coloricon = NSImage(named: NSImage.Name("menuicon"))
        coloricon?.size.width = 18
        coloricon?.size.height = 18
        colorfulIcon.image = coloricon
        
        
        let monochromeIcon = NSImageView(frame:NSRect(x: 205, y:60, width: 50, height: 40))
        
        
        let monoicon = NSImage(named: NSImage.Name("menuicon_mono"))
        monoicon?.size.width = 18
        monoicon?.size.height = 18
        monochromeIcon.image = monoicon
        
        
        let iconOneRadioButton = NSButton(radioButtonWithTitle: "", target: Any?.self, action: #selector(changeIcon))
        iconOneRadioButton.frame = NSRect(x: 200, y: 90, width: 150, height: 25)
        //        iconOneRadioButton.title = "Colorful"
        iconOneRadioButton.title = "     Colorful"
        
        let iconTwoRadioButton = NSButton(radioButtonWithTitle: "", target: Any?.self, action: #selector(changeIcon))
        iconTwoRadioButton.frame = NSRect(x: 200, y: 65, width: 150, height: 25)
        //        iconTwoRadioButton.title = "Monochrome"
        iconTwoRadioButton.title = "     Monochrome"
        if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
            iconTwoRadioButton.state = .on
            iconOneRadioButton.state = .off
        } else {
            iconOneRadioButton.state = .on
            iconTwoRadioButton.state = .off
        }
        if CFPreferencesAppValueIsForced("icon_mode" as CFString, appBundleID as CFString) {
            iconOneRadioButton.isEnabled = false
            iconTwoRadioButton.isEnabled = false
        }
        
        // App info and project link
//        let infoTextView = NSTextField(frame: NSRect(x: 188, y: -40, width: 300, height: 100))
        let infoTextView = NSTextField(frame: NSRect(x: 385, y: 30, width: 300, height: 50))
        infoTextView.font = NSFont.systemFont(ofSize: 16)
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
        
        let linkTextView = NSTextView(frame: NSRect(x: 320, y: 10, width: 300, height: 25))
        linkTextView.textContainerInset = NSSize(width: 10, height: 10)
        linkTextView.isEditable = false
        linkTextView.isSelectable = true
        linkTextView.drawsBackground = false
        let linkString = "https://github.com/boberito/AirDropAssistant"
        let linkAttributeString = NSMutableAttributedString(string: linkString)
        let url = URL(string: "https://github.com/boberito/AirDropAssistant")!
        let linkRange = (linkString as NSString).range(of: url.absoluteString)
        linkAttributeString.addAttribute(.link, value: url, range: linkRange)
        let boldFont = NSFont.systemFont(ofSize: 12)
        linkAttributeString.addAttribute(.font, value: boldFont, range: linkRange)
        linkTextView.textStorage?.setAttributedString(linkAttributeString)
    
        // PF-based direction restrictions
        let restrictLabel = NSTextField(frame: NSRect(x: 20, y: 110, width: 150, height: 25))
        restrictLabel.stringValue = "Restrict AirDrop:"
        restrictLabel.isBordered = false
        restrictLabel.isBezeled = false
        restrictLabel.isEditable = false
        restrictLabel.drawsBackground = false
        
        let restrictRadioButtonOne = NSButton(radioButtonWithTitle: "Allow Both Ways", target: Any.self, action: #selector(pfADARadio))
        restrictRadioButtonOne.frame = NSRect(x: 20, y: 90, width: 150, height: 25)
        
        let restrictRadioButtonTwo = NSButton(radioButtonWithTitle: "Incoming Only", target: Any.self, action: #selector(pfADARadio))
        restrictRadioButtonTwo.frame = NSRect(x: 20, y: 70, width: 150, height: 25)
        
        let restrictRadioButtonThree = NSButton(radioButtonWithTitle: "Outgoing Only", target: Any.self, action: #selector(pfADARadio))
        restrictRadioButtonThree.frame = NSRect(x: 20, y:50, width: 150, height: 25)
        
        if pfADAPref == nil || pfADAPref == "off" {
            restrictRadioButtonOne.state = .on
            restrictRadioButtonTwo.state = .off
            restrictRadioButtonThree.state = .off
            previousRadioButton = restrictRadioButtonOne
        }
        if pfADAPref == "DisableOut" {
            restrictRadioButtonOne.state = .off
            restrictRadioButtonTwo.state = .on
            restrictRadioButtonThree.state = .off
            previousRadioButton = restrictRadioButtonTwo
        }
        if pfADAPref == "DisableIn" {
            restrictRadioButtonOne.state = .off
            restrictRadioButtonTwo.state = .off
            restrictRadioButtonThree.state = .on
            previousRadioButton = restrictRadioButtonThree
        }
        
        // Launch at Login toggle backed by SMAppService
        let startUpButton = NSButton(checkboxWithTitle: "Launch at Login", target: Any?.self, action: #selector(loginItemChange))
        startUpButton.frame = NSRect(x: 20, y: 25, width: 200, height: 25)
        //140
        let appService = SMAppService.agent(plistName: "com.ttinc.Air-Drop-Assistant.plist")
        // Reflect current agent status in the checkbox
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
        
        let appIcon = NSImageView(frame:NSRect(x: 415, y:85, width: 100, height: 100))
        appIcon.image = NSImage(named: "AppIcon")
        
        view.addSubview(iconLabel)
        view.addSubview(colorfulIcon)
        view.addSubview(monochromeIcon)
        view.addSubview(iconOneRadioButton)
        view.addSubview(iconTwoRadioButton)
        view.addSubview(appIcon)
        view.addSubview(infoTextView)
        view.addSubview(linkTextView)
        view.addSubview(startUpButton)
        view.addSubview(airDropSettingButton)
        view.addSubview(airDropSettingLabel)
        view.addSubview(restrictLabel)
        view.addSubview(restrictRadioButtonOne)
        view.addSubview(restrictRadioButtonTwo)
        view.addSubview(restrictRadioButtonThree)
        self.view = view
        
    }
    /// Standard AppKit hook (unused for now).
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    // MARK: - Actions
    /// Persist the selected default AirDrop mode.
    @objc func airDropSelect(_ popUpButton: NSPopUpButton){
        if let selected = popUpButton.titleOfSelectedItem {
            UserDefaults.standard.set(selected, forKey: "airDropSetting")
        }
        
    }
    /// Load the PF restriction value from the app's managed plist under /Library/Preferences.
    func loadPref() {
        
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let path = "/Library/Preferences/\(bundleID).plist"
        if FileManager.default.fileExists(atPath: path) {
            if let plist = NSDictionary(contentsOfFile: path) as? [String: Any] {
                if let adaPFValue = plist["ADA_PF"] as? String {
                    pfADAPref = adaPFValue as String
                    }
            }
        }
    }
    
    /// Persist the selected enforcement delay in minutes.
    @objc func timeLengthSelect(_ popUpButton: NSPopUpButton){
        if let selected = popUpButton.titleOfSelectedItem {
            let min = selected.split(separator: " ")[0]
            let minInt = Int(min)!
            UserDefaults.standard.set(minInt, forKey: "timing")
        }
        
    }

    
    /// Apply PF restriction via helper script. Revert UI if the script indicates failure.
    @objc func pfADARadio(_ sender: NSButton) {
        // Remove PF restrictions
        switch sender.title {
        case "Allow Both Ways":
            if pfADAPref == "DisableOut" || pfADAPref == "DisableIn" {
                if !runPFScript(argument: "--remove") {
                    sender.state = .off
                    previousRadioButton.state = .on
                } else {
                    previousRadioButton = sender
                }
                
            }
        // Block outgoing AirDrop traffic
        case "Incoming Only":
            if pfADAPref != "DisableOut" {
                if !runPFScript(argument: "--blockOut") {
                    sender.state = .off
                    previousRadioButton.state = .on
                } else {
                    previousRadioButton = sender
                }
            }
        // Block incoming AirDrop traffic
        case "Outgoing Only":
            if pfADAPref != "DisableIn" {
                if !runPFScript(argument: "--blockIn") {
                    sender.state = .off
                    previousRadioButton.state = .on
                } else {
                    previousRadioButton = sender
                }
            }
        default:
            NSLog("You crazy you got here")
        }
        loadPref()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.delegate?.updatePF()
        }

        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        self.view.window?.makeKeyAndOrderFront(nil)
        self.view.window?.orderFrontRegardless()
    }
    
    /// Runs the bundled zsh helper script with a specific argument to mutate PF rules.
    /// Returns false if user cancels or script indicates failure.
    func runPFScript(argument: String) -> Bool {
        let resourcesPath = Bundle.main.resourceURL!.appendingPathComponent("ADA_PF_Helper_Script.sh").path
        NSLog("Script Path: \(resourcesPath)")
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = [resourcesPath, argument]  // Correct argument passing
        task.launchPath = "/bin/zsh"
        task.standardInput = nil
        
        task.launch()
        task.waitUntilExit()  // Wait for the task to complete
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        if output.contains("User canceled."){
            return false
        }
        return true
    }
    
    /// Toggle menu bar icon style and notify delegate to refresh the icon immediately.
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
    
    /// Register/unregister the SMAppService agent for Launch at Login, with a cautionary alert.
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
            
            let alert = NSAlert()
            alert.messageText = "Alert"
            alert.informativeText = """
            Air Drop Assistant may quit and need reopened when Launch At Login is unselected.
"""
            alert.runModal()
            
            do {
                if appService.status == .enabled {
                    try appService.unregister()
                    Logger.airdropstatus.info("unregistered service successfully")
                }
                
            } catch {                                
                Logger.airdropstatus.error("Problem unregistering service")
            }
        }
    }
    
}

