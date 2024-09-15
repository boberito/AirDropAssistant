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


class AppDelegate: NSObject, NSApplicationDelegate, DataModelDelegate, PrefDataModelDelegate {
    func checkAirDrop() {
        if domain!.string(forKey: "DiscoverableMode") == UserDefaults.standard.string(forKey: "airDropSetting") || domain!.string(forKey: "DiscoverableMode") == "Off" {
            return
        } else {
            prefWatcher.resetDiscoverableMode()
        }
    }
    
    let nc = UNUserNotificationCenter.current()
    func didReceiveDataUpdate(airDropStatus: String) {
        
        self.adaMenuListing()
    }
    
    func didRecievePrefUpdate(iconMode: String) {
        self.menuIcon()
    }

    let domain = UserDefaults(suiteName: "com.apple.sharingd")
    let adaMenu = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var airDropStatus = ""
    let prefWatcher = PrefWatcher()
    let updater = UpdateCheck()
    let prefViewController = PreferencesViewController()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("ADA Launched")
        
        let appService = SMAppService.agent(plistName: "com.ttinc.Air-Drop-Assistant.plist")
        if CommandLine.arguments.count > 1 {
            if airDropManagedDisabled() {
                print("AirDrop is disabled by an MDM Profile. Please contact your MDM administrator.")
                NSApp.terminate(nil)
            }
            let arguments = CommandLine.arguments
            let stringarguments = String(describing: arguments)
            NSLog(stringarguments)
            
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
        
        if airDropManagedDisabled() {
            let alert = NSAlert()
            alert.messageText = "Alert"
            alert.informativeText = """
AirDrop is disabled by an MDM Profile. Please contact your MDM administrator.
"""
            alert.runModal()
            NSApp.terminate(nil)
        }
        if isAppAlreadyRunning() {
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
        prefViewController.delegate = self
        
        if domain?.string(forKey: "DiscoverableMode") != UserDefaults.standard.string(forKey: "airDropSetting") && domain?.string(forKey: "DiscoverableMode") != "Off" {
            prefWatcher.resetAirDrop()
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
        adaMenu.menu?.insertItem(prefs, at: 1)
        let softwareUpdate = NSMenuItem(title: "Check for Update", action: #selector(updateCheckFunc), keyEquivalent: "")
        adaMenu.menu?.insertItem(softwareUpdate, at: 2)
        let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
        adaMenu.menu?.insertItem(quit, at: 3)
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
        var window: PreferencesWindow?
        let windowSize = NSSize(width: 415, height: 200)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        window = PreferencesWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .titled], backing: .buffered, defer: false)
        window?.title = "Air Drop Assistant Preferences"
        if #available(OSX 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
        window?.contentViewController = prefViewController
//        window?.contentViewController = PreferencesViewController()
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
