//
//  UpdateCheck.swift
//
//  Created by Bob Gendler on 3/25/24.
//
import Cocoa
import os

struct githubData: Decodable {
    let tag_name: String
}

class UpdateCheck {
    func check() -> Int{
        
        let sc_menuURL = "https://api.github.com/repos/boberito/sc_menu/releases/latest"
        var request = URLRequest(url: URL(string: sc_menuURL)!)
        request.timeoutInterval = 3.0
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        var version: String? = nil
        var updateNeeded = 0
        let session = URLSession.shared
        let task = session.dataTask(with: request as URLRequest) {data,response,error in
            let httpResponse = response as? HTTPURLResponse
            let dataReturn = data
            if (error != nil) {
//                os_log("An Error Occured - offline or can't reach GitHub - %s", log: self.updateLog, type: .error, error?.localizedDescription ?? "Unknown Error")
                updateNeeded = 2
                dispatchGroup.leave()
            } else {
                do {
                    switch httpResponse!.statusCode {
                    case 200:
                        let decoder = JSONDecoder()
                        if let githubData = try? decoder.decode(githubData.self, from: dataReturn!) {
                            version = githubData.tag_name
                            if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let gitHubVersion = version {
                                let versionCompare = currentVersion.compare(gitHubVersion, options: .numeric)
                                if versionCompare == .orderedSame {
//                                    os_log("SC Menu is up to date", log: self.updateLog, type: .default)
                                    updateNeeded = 0
                                } else if versionCompare == .orderedAscending {
                                    DispatchQueue.main.async {
                                        self.alert(githubVersion: gitHubVersion, current: currentVersion)
                                    }
//                                    os_log("Current is %s, newest is %s", log: self.updateLog, type: .default, currentVersion.description, gitHubVersion.description)
                                    updateNeeded = 1
                                } else if versionCompare == .orderedDescending {
//                                    os_log("Current is %s, version on GitHub is %s", log: self.updateLog, type: .default, currentVersion.description, gitHubVersion.description)
                                    updateNeeded = 0
                                }
                            }
                        }
                        dispatchGroup.leave()
                    default:
//                        os_log("Offline or cannot reach GitHub", log: self.updateLog, type: .error)
                        updateNeeded = 2
                        dispatchGroup.leave()
                    }
                }
            }
        }
        task.resume()
        dispatchGroup.wait()
        
        return updateNeeded
    }
    
    func alert(githubVersion: String, current: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = """
        An update is available for SC Menu.
        
        Current version is \(current).
        Newest version is \(githubVersion).
        """
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Later")
        let modalResult = alert.runModal()
        
        switch modalResult {
        case .alertFirstButtonReturn: // NSApplication.ModalResponse.alertFirstButtonReturn
            if let url = URL(string: "https://github.com/boberito/sc_menu/releases") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            print("something")
//            os_log("Update later", log: updateLog, type: .default)
        default:
            print("something else")
//            os_log("Somehow closed the alert without pushing a button", log: updateLog, type: .error)
        }
    }
    
}
