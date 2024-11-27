//
//  PreferenceObserver.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 11/27/24.
//
import Combine
import Foundation



extension UserDefaults {
    @objc dynamic var hideMenuIcon: String? {
        return string(forKey: "hideMenuIcon")
    }
    
    @objc dynamic var icon_mode: String? {
        return string(forKey: "icon_mode")
    }
}

protocol AppPrefObserverDelegate {
    func newPreferenceValue()
}

class AppPreferencesObserver {
    
    var delegate: AppPrefObserverDelegate?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let hideMenuIconPref = UserDefaults.standard.publisher(for: \.hideMenuIcon)
        let icon_modePref = UserDefaults.standard.publisher(for: \.icon_mode)
        
        // Combine the two publishers
        Publishers.CombineLatest(hideMenuIconPref, icon_modePref)
            .sink { _, _ in
                self.delegate?.newPreferenceValue()
            }
            .store(in: &cancellables)
    }
}

// Usage

