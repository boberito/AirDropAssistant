//
//  UpdateCheck.swift
//  SC Menu
//
//  Created by Bob Gendler on 3/25/24.
//
import Cocoa
import os
import OSLog

// MARK: - UpdateCheck Overview
// Contacts GitHub Releases to determine if a newer version is available and, if so,
// prompts the user with a modal alert and a link to the releases page.

/// Minimal model for the GitHub releases API response.
struct githubData: Decodable {
    let tag_name: String
}

/// Performs async update checks and presents UI alerts when updates are found.
class UpdateCheck {
    
    // MARK: - Public API
    /// Fetch the latest release tag from GitHub and compare it numerically to the app's version.
    /// On a newer version, present an alert to the user.
    func check() async{
        let sc_menuURL = "https://api.github.com/repos/boberito/AirDropAssistant/releases/latest"
        var request = URLRequest(url: URL(string: sc_menuURL)!)
        // Keep the request short to avoid blocking UI
        request.timeoutInterval = 3.0
        var version: String? = nil
        // Network error or offline; bail out quietly
        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            Logger.updater.error("Offline or cannot reach GitHub")
            return
        }
        
        let httpResponseCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        // Only proceed on success
        if httpResponseCode == 200 {
            // Decode minimal JSON to get tag_name
            let decoder = JSONDecoder()
            if let githubData = try? decoder.decode(githubData.self, from: data) {
                    version = githubData.tag_name
                    if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let gitHubVersion = version {
                        // Compare semantic versions using .numeric
                        let versionCompare = currentVersion.compare(gitHubVersion, options: .numeric)
                        if versionCompare == .orderedSame {
                            Logger.updater.info("ADA is update to date")

                        } else if versionCompare == .orderedAscending {
                            
                            alert(githubVersion: gitHubVersion, current: currentVersion)
                            
                            Logger.updater.info("Current is \(currentVersion.description), newest is \(gitHubVersion.description)")

                        } else if versionCompare == .orderedDescending {
                            Logger.updater.info("Current is \(currentVersion.description), newest is \(gitHubVersion.description)")
                        }
                    }
                }
        }
    }
    
    /// Present a modal alert on the main queue offering to open the releases page.
    func alert(githubVersion: String, current: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Update Available"
            alert.informativeText = """
        An update is available for Air Drop Assistant.
        
        Current version is \(current).
        Newest version is \(githubVersion).
        """
            alert.addButton(withTitle: "Update")
            alert.addButton(withTitle: "Later")
            let modalResult = alert.runModal()
            
            switch modalResult {
            case .alertFirstButtonReturn: // NSApplication.ModalResponse.alertFirstButtonReturn
                if let url = URL(string: "https://github.com/boberito/AirDropAssistant/releases") {
                    NSWorkspace.shared.open(url)
                }
            case .alertSecondButtonReturn:
                Logger.general.log("Update later")
                
            default:
                Logger.general.debug("Somehow closed the alert without pushing a button")
            }
        }
    }
    
}

