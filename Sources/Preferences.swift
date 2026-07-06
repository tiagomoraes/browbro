import AppKit
import Foundation
import ServiceManagement

/// A keyboard modifier the user can hold to summon the picker. Backed by its
/// raw string so it persists cleanly in UserDefaults / `@AppStorage`.
enum TriggerModifier: String, CaseIterable {
    case command, option, control, shift

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .command: .command
        case .option: .option
        case .control: .control
        case .shift: .shift
        }
    }

    /// The glyph shown on the Settings segmented control.
    var symbol: String {
        switch self {
        case .command: "\u{2318}"   // ⌘
        case .option: "\u{2325}"    // ⌥
        case .control: "\u{2303}"   // ⌃
        case .shift: "\u{21E7}"     // ⇧
        }
    }

    var name: String {
        switch self {
        case .command: "Command"
        case .option: "Option"
        case .control: "Control"
        case .shift: "Shift"
        }
    }

    /// Whether this modifier is physically held *right now*. Read the instant a
    /// link arrives (moments after the click), so a still-held key is detected —
    /// this is a snapshot of hardware state and needs no special permission.
    var isHeld: Bool {
        NSEvent.modifierFlags.contains(flag)
    }
}

/// v1 preferences, backed by UserDefaults (Decision: UserDefaults for prefs).
enum Preferences {
    static let rememberLastKey = "rememberLastTarget"
    static let skipSingleKey = "skipPickerForSingleTarget"
    static let onboardingKey = "hasCompletedOnboarding"
    static let lastUsedTargetKey = "lastUsedTargetID"
    static let targetOrderKey = "targetOrder"
    static let hiddenTargetsKey = "hiddenTargets"
    static let requireModifierKey = "requireModifierForPicker"
    static let triggerModifierKey = "triggerModifier"
    static let defaultTargetKey = "defaultTargetID"

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

    /// When on, a plain click opens `defaultTargetID` directly; the picker only
    /// appears while `triggerModifier` is held. Off (default) = always pick.
    static var requireModifierForPicker: Bool {
        get { UserDefaults.standard.bool(forKey: requireModifierKey) }
        set { UserDefaults.standard.set(newValue, forKey: requireModifierKey) }
    }

    /// The key held to summon the picker in modifier mode.
    static var triggerModifier: TriggerModifier {
        get { TriggerModifier(rawValue: UserDefaults.standard.string(forKey: triggerModifierKey) ?? "") ?? .option }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: triggerModifierKey) }
    }

    /// The target a plain click opens in modifier mode. Nil until chosen; the
    /// picker falls back to the top of the catalog.
    static var defaultTargetID: String? {
        get { UserDefaults.standard.string(forKey: defaultTargetKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultTargetKey) }
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
