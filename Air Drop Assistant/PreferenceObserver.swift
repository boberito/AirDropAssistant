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
    
    @objc dynamic var disableUpdates: Bool {
        return bool(forKey: "disableUpdates")
    }
    
    @objc dynamic var timing: Int {
        return integer(forKey: "timing")
    }
    
    @objc dynamic var airDropSetting: String? {
        return string(forKey: "airDropSetting")
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
        let disableUpdatesPref = UserDefaults.standard.publisher(for: \.disableUpdates)
        let timingPref = UserDefaults.standard.publisher(for: \.timing)
        let airDropSettingPref = UserDefaults.standard.publisher(for: \.airDropSetting)
        // Combine the two publishers
        Publishers.CombineLatest3(
                Publishers.CombineLatest(hideMenuIconPref, icon_modePref),
                disableUpdatesPref,
                timingPref
            )
            .combineLatest(airDropSettingPref)
            .sink { _ in
                self.delegate?.newPreferenceValue()
            }
            .store(in: &cancellables)
    }
}

// Usage

