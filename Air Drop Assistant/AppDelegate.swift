//
//  AppDelegate.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 8/16/24.
//

import Cocoa
import UserNotifications
import ServiceManagement
import OSLog
import Sparkle

// MARK: - AppDelegate Overview
// This file contains the main application delegate for Air Drop Assistant.
// Responsibilities:
// - Manage app lifecycle and activation policy (menu bar accessory app)
// - Build and update the status bar menu
// - Observe and react to user preference changes
// - Enforce AirDrop settings and monitor system preference changes
// - Handle update checks and local notifications

/// Main application delegate that coordinates app lifecycle, menu management,
/// preference observation, AirDrop enforcement, and update checks.
@main
class AppDelegate: NSObject, NSApplicationDelegate, DataModelDelegate, PrefDataModelDelegate, AppPrefObserverDelegate {
    // MARK: - Preference Change Handling
    /// Called when any observed preference changes. Rebuilds the status bar icon and menu
    /// to reflect current policy and user defaults (e.g., hidden icon, updates disabled).
    func newPreferenceValue() {
        menuIcon()
        
        guard let appBundleID = Bundle.main.bundleIdentifier else { return }
        let hideMenuIconValue = UserDefaults.standard.bool(forKey: "hideMenuIcon")
        let isForced = CFPreferencesAppValueIsForced("hideMenuIcon" as CFString, appBundleID as CFString)
        
        if hideMenuIconValue && isForced {
            adaMenu.menu?.removeAllItems()
            NSStatusBar.system.removeStatusItem(adaMenu)
        } else {
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
            let isForcedUpdatesDisable = CFPreferencesAppValueIsForced("disableUpdates" as CFString, appBundleID as CFString)
            if UserDefaults.standard.bool(forKey: "disableUpdates") && isForcedUpdatesDisable {
                Logger.general.info("Updates disabled, not adding the update menu")
            } else {
                adaMenu.menu?.insertItem(softwareUpdate, at: 2 + IncreaseByOne)
            }
                let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
            guard let menuCount = adaMenu.menu?.items.count else { return }
                adaMenu.menu?.insertItem(quit, at: menuCount)
        }
    }
    
    /// Ensures AirDrop is aligned with the app's desired state. If the current system
    /// value differs (and isn't Off), triggers a reset back to the preferred setting.
    func checkAirDrop() {
        if domain!.string(forKey: "DiscoverableMode") == UserDefaults.standard.string(forKey: "airDropSetting") || domain!.string(forKey: "DiscoverableMode") == "Off" {
            return
        } else {
            prefWatcher.resetDiscoverableMode()
        }
    }
    let logStreamer = SharingdLogStreamer()
    /// Shared notification center used to request authorization and deliver local notifications.
    let nc = UNUserNotificationCenter.current()
    // MARK: - Menu Updates
    /// Responds to preference file changes by rebuilding the menu items and preserving
    /// the correct ordering of dynamic items (e.g., Incoming/Outgoing only indicators).
    func didReceiveDataUpdate(airDropStatus: String) {
        let hideMenuIconValue = UserDefaults.standard.bool(forKey: "hideMenuIcon")
        if hideMenuIconValue {
           return
        }
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
        
        guard let appBundleID = Bundle.main.bundleIdentifier else { return }
        let isForcedUpdatesDisable = CFPreferencesAppValueIsForced("disableUpdates" as CFString, appBundleID as CFString)
        if UserDefaults.standard.bool(forKey: "disableUpdates") && isForcedUpdatesDisable {
            Logger.general.info("Updates disabled, not adding the update menu")
        } else {
            adaMenu.menu?.insertItem(softwareUpdate, at: 2 + IncreaseByOne)
        }
        
        let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
        guard let menuCount = adaMenu.menu?.items.count else { return }
        self.adaMenu.menu?.insertItem(quit, at: menuCount)
    }
    /// Refreshes the PF (packet filter) status indicator in the menu after the helper
    /// script updates firewall rules for AirDrop direction restrictions.
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
        guard let appBundleID = Bundle.main.bundleIdentifier else { return }
        let isForcedUpdatesDisable = CFPreferencesAppValueIsForced("disableUpdates" as CFString, appBundleID as CFString)
        if UserDefaults.standard.bool(forKey: "disableUpdates") && isForcedUpdatesDisable {
            Logger.general.info("Updates disabled, not adding the update menu")
        } else {
            adaMenu.menu?.insertItem(softwareUpdate, at: 2 + IncreaseByOne)
        }
        
        let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
        guard let menuCount = adaMenu.menu?.items.count else { return }
        self.adaMenu.menu?.insertItem(quit, at: menuCount)
    }
    /// Called by the Preferences UI when the icon mode changes. Updates the status bar icon.
    func didRecievePrefUpdate(iconMode: String) {
        self.menuIcon()
    }
    
    /// Backed UserDefaults domain for sharingd where the AirDrop DiscoverableMode is stored.
    let domain = UserDefaults(suiteName: "com.apple.sharingd")
    /// The status bar item shown in the menu bar. Hosts the Air Drop Assistant menu.
    var adaMenu = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    /// Cached text for the current AirDrop status displayed in the menu.
    var airDropStatus = ""
    /// Monitors the sharingd preferences file for changes and triggers resets as needed.
    let prefWatcher = PrefWatcher()
    /// Handles asynchronous GitHub release checks and user alerts for updates.
    let updater = UpdateCheck()
    /// Observes app preferences (UserDefaults) using Combine and notifies this delegate on changes.
    let observer = AppPreferencesObserver()
    // MARK: - App Lifecycle
    /// Prevents showing a Dock/window when reopened; keep the app as a menu bar accessory.
    ///
    private lazy var updaterController: SPUStandardUpdaterController = {
           SPUStandardUpdaterController(
               startingUpdater: true,
               updaterDelegate: nil,
               userDriverDelegate: nil
           )
       }()
    
    @IBAction func checkForUpdates(_ sender: Any?) {
            updaterController.checkForUpdates(sender)
        }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.accessory)
        return false
    }
    /// Primary launch sequence:
    /// - Configure as an accessory app (menu bar only)
    /// - Handle CLI registration/unregistration of the login item agent
    /// - Enforce MDM restrictions for AirDrop where applicable
    /// - Prompt for Launch at Login on first run
    /// - Initialize defaults for timing and AirDrop setting
    /// - Start preference observers and file monitoring
    /// - Optionally check for updates and build the status menu
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger.general.info("ADA Launched")
        
        NSApp.setActivationPolicy(.accessory)
        
        // Configure the launch agent used for Launch at Login and handle CLI arguments
        let appService = SMAppService.agent(plistName: "com.ttinc.Air-Drop-Assistant.plist")
        if CommandLine.arguments.count > 1 {
            
            // If MDM disables AirDrop, exit early when running CLI operations
            if airDropManagedDisabled() {
                Logger.general.info("AirDrop is disabled by an MDM Profile. Please contact your MDM administrator.")
                NSApp.terminate(nil)
            }
            let arguments = CommandLine.arguments
           
            // Register the login item agent (and ensure only one ADA instance runs)
            if arguments[1] == "--register" {
                let ADAPids = NSRunningApplication.runningApplications(withBundleIdentifier: "com.ttinc.Air-Drop-Assistant")
                if ADAPids.count > 1 {
                    ADAPids[0].terminate()
                }
                                
                do {
                    try appService.register()
                    Logger.general.info("registered service")
                } catch {
                    Logger.general.error("Problem registering service")
                }
            }
            
            // Unregister the login item agent if currently enabled
            if arguments[1] == "--unregister" {
                do {
                    if appService.status == .enabled {
                        try appService.unregister()
                        
                        Logger.general.info("Unregistered service")
                    }
                    
                } catch {
                    
                    Logger.general.error("Problem unregistering service")
                }
                
            }
#if !DEBUG
            NSApp.terminate(nil)
#endif
        }
        // Ensure only a single instance of the app is running
        if isAppAlreadyRunning() {
            NSApp.terminate(nil)
        }
        // Respect MDM restrictions and alert the user if AirDrop is disabled by policy
        if airDropManagedDisabled() {
            let alert = NSAlert()
            alert.messageText = "Alert"
            alert.informativeText = """
AirDrop is disabled by an MDM Profile. Please contact your MDM administrator.
"""
            alert.runModal()
            NSApp.terminate(nil)
        }
        
        // First launch: ask the user if ADA should be allowed to launch at login
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
                    Logger.general.info("Registered service")
                } catch {
                    Logger.general.error("problem registering service \(error.localizedDescription)")
                }
            }
            
            
            
        }
        // Mark first-launch prompt as completed
        UserDefaults.standard.setValue(true, forKey: "afterFirstLaunch")
        UNUserNotificationCenter.current().delegate = self
        NSApplication.shared.setActivationPolicy(.accessory)
        // Request local notification authorization for status change alerts
        self.notificationPermissions()
        
        
        // Seed default AirDrop setting if not present
        if UserDefaults.standard.string(forKey: "airDropSetting") == nil {
            UserDefaults.standard.set("Contacts Only", forKey: "airDropSetting")
        }
        
        // Seed default timing (minutes) for automatic reset
        if UserDefaults.standard.string(forKey: "timing") == nil {
            UserDefaults.standard.set(15, forKey: "timing")
        }
        // Wire up delegates for preference watching and updates
        prefWatcher.delegate = self
        observer.delegate = self
        
        // If current system AirDrop setting is out of compliance, schedule a reset
        if domain?.string(forKey: "DiscoverableMode") != UserDefaults.standard.string(forKey: "airDropSetting") && domain?.string(forKey: "DiscoverableMode") != "Off" {
            Task {
                await prefWatcher.resetAirDrop()
            }
        }
        
        // Prepare path to the sharingd preferences file and start monitoring
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let pathToPref = "\(homeDirURL.path)/Library/Preferences/com.apple.sharingd.plist"
        prefWatcher.filePath = pathToPref
        
        
        guard let appBundleID = Bundle.main.bundleIdentifier else { return }
        
        // Determine whether the menu bar icon is forced hidden by managed preferences
        let hideMenuIconValue = UserDefaults.standard.bool(forKey: "hideMenuIcon")
        let isForced = CFPreferencesAppValueIsForced("hideMenuIcon" as CFString, appBundleID as CFString)
        
        if hideMenuIconValue && isForced {
            prefWatcher.startMonitoring()
        } else {
            // Optionally perform update check if not disabled by managed preferences
            let isForcedUpdatesDisable = CFPreferencesAppValueIsForced("disableUpdates" as CFString, appBundleID as CFString)
            if UserDefaults.standard.bool(forKey: "disableUpdates") && isForcedUpdatesDisable {
                Logger.general.info("Updates disabled")
            } else {
                updaterController.updater.checkForUpdatesInBackground()
//                Task {
//                    await updater.check()
//                }
            }
            // Build the initial status bar menu with dynamic items and actions
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
            if UserDefaults.standard.bool(forKey: "disableUpdates") && isForcedUpdatesDisable {
                Logger.general.info("Updates disabled, not adding the update menu")
            } else {
                adaMenu.menu?.insertItem(softwareUpdate, at: 2 + IncreaseByOne)
            }
            
            let quit = NSMenuItem(title: "Quit", action: #selector(QuitApp), keyEquivalent: "")
            guard let menuCount = adaMenu.menu?.items.count else { return }
            adaMenu.menu?.insertItem(quit, at: menuCount)
            do {
//                try SharingdLogStreamer().start()
                if logStreamer.checkProfileStatus()  {
                    try logStreamer.start()
                }
            } catch {
                print("logging failed")
            }
            prefWatcher.startMonitoring()
        }
        
    }
    
    // MARK: - Notifications
    /// Requests authorization for delivering local notifications when AirDrop status changes.
    func notificationPermissions() {
        nc.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if granted {
                self.prefWatcher.notificationsAllow = true
                
            }
        }
        
    }
    
    // MARK: - Menu Icon
    /// Applies the selected icon mode (colorful/monochrome) to the status bar item.
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
    
    // MARK: - Menu Construction
    /// Inserts the current AirDrop status and optional PF restriction indicators into the menu.
    /// Ensures duplicate indicators are removed before inserting the current state.
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
    
    /// Tracks user consent for Launch at Login from the Preferences UI.
    @objc func launchAtLogin(){
        Logger.general.info("Launch at Loging Function")
        
        UserDefaults.standard.setValue(true, forKey: "afterFirstLaunch")
    }
    /// Quits the application.
    @objc func QuitApp() {
        logStreamer.stop()
        exit(0)
    }
    /// Presents the Preferences window (centers on screen, reuses existing window if open).
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
    // MARK: - Termination
    /// Placeholder for any cleanup needed when the app is terminating.
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        if logStreamer.checkStatus() {
            logStreamer.stop()
        }
    }
    
    /// Opt-in to secure state restoration on newer macOS versions.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    // MARK: - Utilities
    /// Returns true if another instance of this app bundle is already running.
    func isAppAlreadyRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { app in
            return app.bundleIdentifier == Bundle.main.bundleIdentifier && app != NSRunningApplication.current
        }
        return isRunning
    }
    /// Manually trigger an asynchronous update check (from the menu item).
    @objc func updateCheckFunc (){
//        Task {

//            await updater.check()
//           updaterController.updater.checkForUpdatesInBackground()
        self.checkForUpdates(nil)
            
//        }
    }
    /// Detects whether AirDrop is disabled by system/MDM configuration profiles by checking
    /// com.apple.NetworkBrowser and com.apple.applicationaccess preferences.
    func airDropManagedDisabled () -> Bool {
        let networkBrowser = UserDefaults(suiteName: "com.apple.NetworkBrowser")
        if let networkBrowserAirDrop = networkBrowser?.bool(forKey: "DisableAirDrop") {
            if networkBrowserAirDrop {
                Logger.general.info("com.apple.NetworkBrowser DisableAirDrop is set to true")
                return true
            }
        }
        if let value = UserDefaults.standard.persistentDomain(forName: "com.apple.applicationaccess")?["allowAirDrop"] {
            if let boolValue = value as? Bool {
                if !boolValue {
                    Logger.general.info("com.apple.applicationaccess allowAirDrop is set to false")
                    return true
                }
                
            }
        }
        return false
    }
}



extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Display incoming notifications as banners while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler(.banner)
    }
    
}

