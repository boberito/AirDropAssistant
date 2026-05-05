//
//  PreferenceObserver.swift
//  Air Drop Assistant
//
//  Created by Bob Gendler on 11/27/24.
//

import Combine
import Foundation

// MARK: - PreferenceObserver Overview
// Bridges UserDefaults changes into Combine publishers and notifies a delegate when
// any relevant preference changes. Used by AppDelegate to rebuild UI/menu state.

/// KVO-compliant dynamic properties for the specific preferences we observe.
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

/// Delegate notified whenever any of the observed preferences change.
protocol AppPrefObserverDelegate {
    func newPreferenceValue()
}

/// Observes app preferences and notifies delegate on any change.
class AppPreferencesObserver {
    
    /// Target delegate to notify on preference changes
    var delegate: AppPrefObserverDelegate?
    /// Retains Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup
    /// Set up Combine pipelines to observe multiple preferences and coalesce changes.
    init() {
        // Publisher for hideMenuIcon
        let hideMenuIconPref = UserDefaults.standard.publisher(for: \.hideMenuIcon)
        // Publisher for icon_mode
        let icon_modePref = UserDefaults.standard.publisher(for: \.icon_mode)
        // Publisher for disableUpdates
        let disableUpdatesPref = UserDefaults.standard.publisher(for: \.disableUpdates)
        // Publisher for timing
        let timingPref = UserDefaults.standard.publisher(for: \.timing)
        // Publisher for airDropSetting
        let airDropSettingPref = UserDefaults.standard.publisher(for: \.airDropSetting)
        // Merge: (hideMenuIcon, icon_mode) + disableUpdates + timing, then combine with airDropSetting
        Publishers.CombineLatest3(
                Publishers.CombineLatest(hideMenuIconPref, icon_modePref),
                disableUpdatesPref,
                timingPref
            )
            .combineLatest(airDropSettingPref)
            // Coalesce into a single callback to rebuild UI/menu
            .sink { _ in
                self.delegate?.newPreferenceValue()
            }
            .store(in: &cancellables)
    }
}

