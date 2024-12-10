//
//  AppDelegate.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/16/24.
//

import Cocoa
import UserNotifications
import ServiceManagement

@NSApplicationMain


class AppDelegate: NSObject, NSApplicationDelegate, DataModelDelegate, PrefDataModelDelegate, AppPrefObserverDelegate {
    func newPreferenceValue() {
        menuIcon()
        
        guard let appBundleID = Bundle.main.bundleIdentifier else { return }
        let hideMenuIconValue = UserDefaults.standard.bool(forKey: "hideMenuIcon")
        let isForced = CFPreferencesAppValueIsForced("hideMenuIcon" as CFString, appBundleID as CFString)
        
        if hideMenuIconValue && isForced {
            adaMenu.menu?.removeAllItems()
            NSStatusBar.system.removeStatusItem(adaMenu)
        } else {
            guard adaMenu.menu != nil else { return }
                adaMenu = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                
                adaMenu.menu = NSMenu()
                
                menuIcon()
                
                adaMenuListing()
                let prefs = NSMenuItem(title: "Preferences", action: #selector(Preferences), keyEquivalent: "")
                let softwareUpdate = NSMenuItem(title: "Check for Update", action: #selector(updateCheckFunc), keyEquivalent: "")
                
                var IncreaseByOne: Int = 0
                if let menuItems = adaMenu.menu {
                    for item in menuItems.items {
                        
                        if item.title == "AirDrop: Incoming Only"{
                            IncreaseByOne += 1
                        }
                        if  item.title == "AirDrop: Outgoing Only" {
                            IncreaseByOne += 1
                        }
                    }
                }
                
                adaMenu.menu?.insertItem(prefs, at: 1 + IncreaseByOne)
                adaMenu.menu?.insertItem(softwareUpdate, at: 2 + IncreaseByOne)
                let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
                adaMenu.menu?.insertItem(quit, at: 3 + IncreaseByOne)
        }
    }
    
    func checkAirDrop() {
        if domain!.string(forKey: "DiscoverableMode") == UserDefaults.standard.string(forKey: "airDropSetting") || domain!.string(forKey: "DiscoverableMode") == "Off" {
            return
        } else {
            prefWatcher.resetDiscoverableMode()
        }
    }
    
    let nc = UNUserNotificationCenter.current()
    func didReceiveDataUpdate(airDropStatus: String) {
        
        self.adaMenu.menu?.removeAllItems()
        self.adaMenu.menu = NSMenu()
        
        self.adaMenuListing()
        let prefs = NSMenuItem(title: "Preferences", action: #selector(Preferences), keyEquivalent: "")
        let softwareUpdate = NSMenuItem(title: "Check for Update", action: #selector(updateCheckFunc), keyEquivalent: "")
        
        var IncreaseByOne: Int = 0
        if let menuItems = adaMenu.menu {
            for item in menuItems.items {
                
                if item.title == "AirDrop: Incoming Only"{
                    IncreaseByOne += 1
                }
                if  item.title == "AirDrop: Outgoing Only" {
                    IncreaseByOne += 1
                }
            }
        }
        
        self.adaMenu.menu?.insertItem(prefs, at: 1 + IncreaseByOne)
        self.adaMenu.menu?.insertItem(softwareUpdate, at: 2 + IncreaseByOne)
        let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
        self.adaMenu.menu?.insertItem(quit, at: 3 + IncreaseByOne)
    }
    func updatePF() {
        
        self.adaMenu.menu?.removeAllItems()
        self.adaMenu.menu = NSMenu()
        
        self.adaMenuListing()
        let prefs = NSMenuItem(title: "Preferences", action: #selector(Preferences), keyEquivalent: "")
        let softwareUpdate = NSMenuItem(title: "Check for Update", action: #selector(updateCheckFunc), keyEquivalent: "")
        
        var IncreaseByOne: Int = 0
        if let menuItems = adaMenu.menu {
            for item in menuItems.items {
                
                if item.title == "AirDrop: Incoming Only"{
                    IncreaseByOne += 1
                }
                if  item.title == "AirDrop: Outgoing Only" {
                    IncreaseByOne += 1
                }
            }
        }
        
        self.adaMenu.menu?.insertItem(prefs, at: 1 + IncreaseByOne)
        self.adaMenu.menu?.insertItem(softwareUpdate, at: 2 + IncreaseByOne)
        let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
        self.adaMenu.menu?.insertItem(quit, at: 3 + IncreaseByOne)
    }
    func didRecievePrefUpdate(iconMode: String) {
        self.menuIcon()
    }
    
    let domain = UserDefaults(suiteName: "com.apple.sharingd")
    var adaMenu = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var airDropStatus = ""
    let prefWatcher = PrefWatcher()
    let updater = UpdateCheck()
    let observer = AppPreferencesObserver()
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Ensure that the app doesn't show the menu bar or Dock icon when reopened
        NSApp.setActivationPolicy(.accessory)
        return false
    }
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("ADA Launched")
        
        NSApp.setActivationPolicy(.accessory)
        
        let appService = SMAppService.agent(plistName: "com.ttinc.Air-Drop-Assistant.plist")
        if CommandLine.arguments.count > 1 {
            if airDropManagedDisabled() {
                print("AirDrop is disabled by an MDM Profile. Please contact your MDM administrator.")
                NSApp.terminate(nil)
            }
            let arguments = CommandLine.arguments
            
            if arguments[1] == "--register" {
                do {
                    try appService.register()
                    NSLog("registered service")
                } catch {
                    NSLog("problem registering service")
                }
            }
            
            if arguments[1] == "--unregister" {
                do {
                    if appService.status == .enabled {
                        try appService.unregister()
                        
                        NSLog("unregistered service")
                    }
                    
                } catch {
                    
                    NSLog("problem unregistering service")
                }
                
            }
            NSApp.terminate(nil)
        }
        if isAppAlreadyRunning() {
            NSApp.terminate(nil)
        }
        if airDropManagedDisabled() {
            let alert = NSAlert()
            alert.messageText = "Alert"
            alert.informativeText = """
AirDrop is disabled by an MDM Profile. Please contact your MDM administrator.
"""
            alert.runModal()
            NSApp.terminate(nil)
        }
        
        if UserDefaults.standard.bool(forKey: "afterFirstLaunch") == false && appService.status != .enabled {
            
            let alert = NSAlert()
            alert.messageText = "First Launch"
            alert.informativeText = """
        Would you like to allow Air Drop Assistant to launch at login?
"""
            alert.addButton(withTitle: "Yes")
            alert.addButton(withTitle: "No")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                
                do {
                    try appService.register()
                    NSLog("registered service")
                } catch {
                    NSLog("problem registering service")
                }
            }
            
            
            
        }
        UserDefaults.standard.setValue(true, forKey: "afterFirstLaunch")
        UNUserNotificationCenter.current().delegate = self
        NSApplication.shared.setActivationPolicy(.accessory)
        self.notificationPermissions()
        
        
        if UserDefaults.standard.string(forKey: "airDropSetting") == nil {
            UserDefaults.standard.set("Contacts Only", forKey: "airDropSetting")
        }
        
        if UserDefaults.standard.string(forKey: "timing") == nil {
            UserDefaults.standard.set(15, forKey: "timing")
        }
        prefWatcher.delegate = self
        observer.delegate = self
        
        if domain?.string(forKey: "DiscoverableMode") != UserDefaults.standard.string(forKey: "airDropSetting") && domain?.string(forKey: "DiscoverableMode") != "Off" {
            Task {
                await prefWatcher.resetAirDrop()
            }
        }
        
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let pathToPref = "\(homeDirURL.path)/Library/Preferences/com.apple.sharingd.plist"
        prefWatcher.filePath = pathToPref
        
        
        guard let appBundleID = Bundle.main.bundleIdentifier else { return }
        
        let hideMenuIconValue = UserDefaults.standard.bool(forKey: "hideMenuIcon")
        let isForced = CFPreferencesAppValueIsForced("hideMenuIcon" as CFString, appBundleID as CFString)
        
        if hideMenuIconValue && isForced {
            prefWatcher.startMonitoring()
        } else {
            _ = updater.check()
            adaMenu.menu = NSMenu()
            
            self.menuIcon()
            
            adaMenuListing()
            let prefs = NSMenuItem(title: "Preferences", action: #selector(Preferences), keyEquivalent: "")
            let softwareUpdate = NSMenuItem(title: "Check for Update", action: #selector(updateCheckFunc), keyEquivalent: "")
            
            var IncreaseByOne: Int = 0
            if let menuItems = adaMenu.menu {
                for item in menuItems.items {
                    
                    if item.title == "AirDrop: Incoming Only"{
                        IncreaseByOne += 1
                    }
                    if  item.title == "AirDrop: Outgoing Only" {
                        IncreaseByOne += 1
                    }
                }
            }
            
            adaMenu.menu?.insertItem(prefs, at: 1 + IncreaseByOne)
            adaMenu.menu?.insertItem(softwareUpdate, at: 2 + IncreaseByOne)
            let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
            adaMenu.menu?.insertItem(quit, at: 3 + IncreaseByOne)
            prefWatcher.startMonitoring()
        }
        
    }
    
    func notificationPermissions() {
        nc.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if granted {
                self.prefWatcher.notificationsAllow = true
                
            }
        }
        
    }
    
    func menuIcon(){
        let iconPref = UserDefaults.standard.string(forKey: "icon_mode") ?? "colorful"
        var menuIcon = "menuicon"
        
        if iconPref == "bw" {
            menuIcon = "menuicon_mono"
        }
        let icon = NSImage(named: NSImage.Name(menuIcon))
        icon?.size.width = 18
        icon?.size.height = 18
        self.adaMenu.button?.image = icon
        
    }
    
    func adaMenuListing(){
        
        var PFADAStatus: String?
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let path = "/Library/Preferences/\(bundleID).plist"
        
        if FileManager.default.fileExists(atPath: path) {
            
            if let plist = NSDictionary(contentsOfFile: path) as? [String: Any] {
                
                if let adaPFValue = plist["ADA_PF"] as? String {
                    
                    PFADAStatus = adaPFValue as String
                    }
            }
        }
            
        if let airDropPref = domain?.object(forKey: "DiscoverableMode") {
            airDropStatus = "Airdrop Status: " + String(describing: airDropPref)
        } else {
            airDropStatus = "Error reading AirDrop Status"
        }
        let airDropStatus = NSMenuItem(title: airDropStatus, action: nil, keyEquivalent: "")
        
        if adaMenu.menu?.items.count != 0 {
            adaMenu.menu?.removeItem(at: 0)
        }
        
        adaMenu.menu?.insertItem(airDropStatus, at: 0)
        if (PFADAStatus != "" || PFADAStatus != "off") && airDropStatus.title != "Airdrop Status: Off" {
            var status = String()
            if PFADAStatus == "DisableOut" {
                status = "AirDrop: Incoming Only"
            }
            if PFADAStatus == "DisableIn" {
                status = "AirDrop: Outgoing Only"
            }
            if status != "" {
                if let menuItems = adaMenu.menu {
                    for item in menuItems.items {
                        if item.title == "AirDrop: Incoming Only"{
                            adaMenu.menu?.removeItem(at: 1)
                        }
                        if  item.title == "AirDrop: Outgoing Only" {
                            adaMenu.menu?.removeItem(at: 1)
                        }
                    }
                }
                adaMenu.menu?.insertItem(NSMenuItem(title: status, action: nil, keyEquivalent: ""), at: 1)
            }
        }
   
        
    }
    
    @objc func launchAtLogin(){
        NSLog("launchatlogin function")
        
        UserDefaults.standard.setValue(true, forKey: "afterFirstLaunch")
    }
    @objc func QuitApp() {
        exit(0)
    }
    @objc func Preferences() {
        for currentWindow in NSApplication.shared.windows {
            if currentWindow.title.contains("Air Drop Assistant Preferences") {
                if #available(OSX 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
                return
            }
        }
        let prefViewController = PreferencesViewController()
        prefViewController.delegate = self
        var window: PreferencesWindow?
        let windowSize = NSSize(width: 415, height: 200)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        window = PreferencesWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .titled], backing: .buffered, defer: false)
        window?.title = "Air Drop Assistant Preferences"
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        window?.contentViewController = prefViewController
    }
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    func isAppAlreadyRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { app in
            return app.bundleIdentifier == Bundle.main.bundleIdentifier && app != NSRunningApplication.current
        }
        return isRunning
    }
    @objc func updateCheckFunc () {
        _ = updater.check()
    }
    func airDropManagedDisabled () -> Bool {
        let networkBrowser = UserDefaults(suiteName: "com.apple.NetworkBrowser")
        if let networkBrowserAirDrop = networkBrowser?.bool(forKey: "DisableAirDrop") {
            if networkBrowserAirDrop {
                NSLog("com.apple.NetworkBrowser DisableAirDrop is set to true")
                return true
            }
        }
        if let value = UserDefaults.standard.persistentDomain(forName: "com.apple.applicationaccess")?["allowAirDrop"] {
            if let boolValue = value as? Bool {
                if !boolValue {
                    NSLog("com.apple.applicationaccess allowAirDrop is set to false")
                    return true
                }
                
            }
        }
        return false
    }
}



extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler(.banner)
    }
    
}
