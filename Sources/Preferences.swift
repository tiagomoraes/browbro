import Foundation
import ServiceManagement

/// v1 preferences, backed by UserDefaults (Decision: UserDefaults for prefs).
enum Preferences {
    static let rememberLastKey = "rememberLastTarget"
    static let skipSingleKey = "skipPickerForSingleTarget"
    static let onboardingKey = "hasCompletedOnboarding"
    static let lastUsedTargetKey = "lastUsedTargetID"
    static let targetOrderKey = "targetOrder"
    static let hiddenTargetsKey = "hiddenTargets"

    /// Pre-highlight whatever you picked last time.
    static var rememberLast: Bool {
        get { UserDefaults.standard.bool(forKey: rememberLastKey) }
        set { UserDefaults.standard.set(newValue, forKey: rememberLastKey) }
    }

    /// If only one browser is shown, just open it.
    static var skipSingle: Bool {
        get { UserDefaults.standard.bool(forKey: skipSingleKey) }
        set { UserDefaults.standard.set(newValue, forKey: skipSingleKey) }
    }

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    static var lastUsedTargetID: String? {
        get { UserDefaults.standard.string(forKey: lastUsedTargetKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastUsedTargetKey) }
    }
}

/// Keep BrowBro ready so the picker is instant (login item via SMAppService).
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
