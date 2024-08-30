//
//  AppDelegate.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/16/24.
//

import Cocoa
import UserNotifications

@NSApplicationMain


class AppDelegate: NSObject, NSApplicationDelegate, DataModelDelegate {
    let nc = UNUserNotificationCenter.current()
    func didReceiveDataUpdate(airDropStatus: String) {
        
        self.adaMenuListing()
    }

    let domain = UserDefaults(suiteName: "com.apple.sharingd")
    let adaMenu = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var airDropStatus = ""
    let prefWatcher = PrefWatcher()
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        self.notificationPermissions()
        if UserDefaults.standard.string(forKey: "airDropSetting") == nil {
            UserDefaults.standard.set("Contacts Only", forKey: "airDropSetting")
        }
        
        if UserDefaults.standard.string(forKey: "timing") == nil {
            UserDefaults.standard.set(15, forKey: "timing")
        }
        
        prefWatcher.delegate = self
        
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
            adaMenu.menu = NSMenu()
            
            if let fileURLString = Bundle.main.path(forResource: "menuicon", ofType: "png") {
                let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                if fileExists {
                    if let button = self.adaMenu.button {
                        button.image = NSImage(byReferencingFile: fileURLString)
                    }
                }
            } else {
                self.adaMenu.button?.title = "ADA"
            }
            
        
        adaMenuListing()
        let prefs = NSMenuItem(title: "Preferences", action: #selector(Preferences), keyEquivalent: "")
        adaMenu.menu?.insertItem(prefs, at: 1)
        let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
        adaMenu.menu?.insertItem(quit, at: 2)
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
    
    func adaMenuListing(){
        if let airDropPref = domain?.object(forKey: "DiscoverableMode") {
            airDropStatus = String(describing: airDropPref)
        } else {
            airDropStatus = "Error reading AirDrop Status"
        }
        let airDropStatus = NSMenuItem(title: airDropStatus, action: nil, keyEquivalent: "")
        
        if adaMenu.menu?.items.count != 0 {
            adaMenu.menu?.removeItem(at: 0)
        }
        
        adaMenu.menu?.insertItem(airDropStatus, at: 0)
        
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
        window?.contentViewController = PreferencesViewController()
    }
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}



