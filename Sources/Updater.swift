import AppKit
import Observation
import Sparkle

/// Owns Sparkle's updater and exposes a small, SwiftUI-friendly surface for the
/// "Check for Updates…" affordances in Settings and the menu-bar dropdown.
///
/// BrowBro ships outside the App Store (DMG + Homebrew cask), so it can't rely
/// on the App Store to deliver updates. Sparkle is the standard for this: it
/// checks a signed appcast, and — when the user accepts — downloads, verifies,
/// and installs the new build in place, then relaunches. Trust is anchored on
/// the EdDSA public key in Info.plist (`SUPublicEDKey`), independent of Apple
/// notarization; Sparkle-installed updates also skip the Gatekeeper quarantine
/// prompt the first manual download shows. See docs/UPDATES.md.
@MainActor
@Observable
final class UpdaterController {
    static let shared = UpdaterController()

    /// Sparkle's standard controller. `startingUpdater: true` kicks off the
    /// scheduled background checks; it also owns the standard update UI (the
    /// window with release notes and the Install button).
    @ObservationIgnored
    private let controller: SPUStandardUpdaterController

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
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
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
    /// open behind whatever the user is looking at.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}
