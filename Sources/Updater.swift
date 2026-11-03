#if SPARKLE
import AppKit
import Observation
import Sparkle
import os

private let updateLog = Logger(subsystem: "cloud.tiagomoraes.browbro", category: "updates")

/// Owns Sparkle's updater and exposes a small, SwiftUI-friendly surface for the
/// "Check for Updates…" affordances in Settings and the menu-bar dropdown.
///
/// BrowBro ships outside the App Store (DMG + Homebrew cask), so it can't rely
/// on the App Store to deliver updates. Sparkle is the standard for this: it
/// checks a signed appcast, and — when the user accepts — downloads, verifies,
/// and installs the new build in place, then relaunches. Trust is anchored on
/// the EdDSA public key in Info.plist (`SUPublicEDKey`), independent of the
/// Developer ID signature Apple checks — an update has to satisfy both, and the
/// stable EdDSA key is what lets the signing identity rotate without stranding
/// installed copies. See docs/UPDATES.md.
@MainActor
@Observable
final class UpdaterController {
    static let shared = UpdaterController()

    /// Sparkle's standard controller. `startingUpdater: true` kicks off the
    /// scheduled background checks; it also owns the standard update UI (the
    /// window with release notes and the Install button).
    @ObservationIgnored
    private let controller: SPUStandardUpdaterController

    /// Sparkle keeps its user-driver delegate weakly; this is the owner.
    @ObservationIgnored
    private let reminders: GentleReminders

    /// Mirrors `SPUUpdater.canCheckForUpdates` so the button can disable itself
    /// while a check is already in flight.
    private(set) var canCheckForUpdates = false

    /// Whether Sparkle checks for updates on its own schedule. Bound to the
    /// Settings toggle; Sparkle persists the choice in the app's UserDefaults.
    var automaticallyChecksForUpdates: Bool {
        didSet {
            controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    @ObservationIgnored
    private var canCheckObservation: NSKeyValueObservation?

    private init() {
        let reminders = GentleReminders()
        self.reminders = reminders
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: reminders)
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        canCheckForUpdates = controller.updater.canCheckForUpdates
        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates, options: [.initial, .new]
        ) { [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    /// Show Sparkle's update dialog. Brings the app forward first: BrowBro is an
    /// `LSUIElement` accessory, so without activation the update window could
    /// open behind whatever the user is looking at. With a gentle reminder
    /// pending, this is what brings that already-found update into focus.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}

/// A scheduled check found an update that is waiting for the user's attention
/// (see `GentleReminders`). Observed by the menu-bar glyph (badge) and the
/// dropdown ("Update available" row). Kept apart from `UpdaterController` so
/// drawing the status item at launch doesn't construct the updater early.
@MainActor
@Observable
final class UpdateReminder {
    static let shared = UpdateReminder()
    private init() {}

    /// Display version of the waiting update, nil when there's nothing to show.
    fileprivate(set) var pendingVersion: String?
}

/// Sparkle's gentle scheduled-update reminders, shaped for a menu-bar app.
///
/// BrowBro is `LSUIElement`: left alone, Sparkle shows a scheduled update alert
/// *behind* whatever the user is doing (it won't steal focus from a background
/// app), where it's easy to never notice. So: when Sparkle would show the update
/// in immediate, utmost focus (right after launch), let it. Otherwise take over
/// showing it, and surface a quiet indicator instead — a badge on the status
/// item and an "Update available" row in the dropdown, which reopens Sparkle's
/// window. The indicator clears once the user looks at the update, or when the
/// update session ends. No notifications, so no new permission.
/// https://sparkle-project.org/documentation/gentle-reminders/
private final class GentleReminders: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        // Sparkle is showing it (user-initiated, or in focus): nothing to add.
        guard !handleShowingUpdate else {
            updateLog.info("Sparkle shows update \(update.displayVersionString, privacy: .public) itself (user-initiated: \(state.userInitiated, privacy: .public))")
            return
        }
        let version = update.displayVersionString
        updateLog.info("scheduled update \(version, privacy: .public) found in the background; showing a gentle reminder")
        MainActor.assumeIsolated { UpdateReminder.shared.pendingVersion = version }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        updateLog.info("update \(update.displayVersionString, privacy: .public) got the user's attention; clearing reminder")
        MainActor.assumeIsolated { UpdateReminder.shared.pendingVersion = nil }
    }

    func standardUserDriverWillFinishUpdateSession() {
        updateLog.info("update session finished; clearing reminder")
        MainActor.assumeIsolated { UpdateReminder.shared.pendingVersion = nil }
    }
}
#endif
