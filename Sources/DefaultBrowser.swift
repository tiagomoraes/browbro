import AppKit

/// Reads and sets the system default web browser, preserving whatever was the
/// default *before* BrowBro took over so it can be shown as a target and
/// restored later (Decision 5: transparent, reversible takeover).
@MainActor
enum DefaultBrowser {
    static let priorDefaultKey = "priorDefaultBrowserBundleID"

    private static let probeURL = URL(string: "https://example.com")!

    /// The app macOS would currently use to open an https link.
    static func currentURL() -> URL? {
        NSWorkspace.shared.urlForApplication(toOpen: probeURL)
    }

    static func currentBundleID() -> String? {
        guard let url = currentURL() else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    static var isBrowBro: Bool {
        currentBundleID() == Bundle.main.bundleIdentifier
    }

    /// BrowBro's bundle id before the rename (CHANGELOG, Unreleased). An old
    /// 0.1.x install can still be registered — even still be the default — and
    /// it is never "the previous browser" or a launch target: handing a link
    /// to it would just bounce it into another copy of BrowBro.
    nonisolated static let legacyBundleID = "so.aca.browbro"

    /// Any BrowBro, this build or a pre-rename one.
    nonisolated static func isBrowBro(bundleID: String?, current: String? = Bundle.main.bundleIdentifier) -> Bool {
        guard let bundleID else { return false }
        return bundleID == current || bundleID == legacyBundleID
    }

    /// Remember the current default as "the previous browser" whenever it is
    /// something other than BrowBro. Called on launch, when Settings / the menu
    /// / onboarding show, and right before taking over — so "Restore previous"
    /// gives back the browser the user had most recently, not whichever one was
    /// default the first time BrowBro ever ran.
    static func capturePriorDefault() {
        if let id = currentBundleID(), shouldCapture(currentDefault: id) {
            UserDefaults.standard.set(id, forKey: priorDefaultKey)
        }
    }

    nonisolated static func shouldCapture(currentDefault: String?,
                                          me: String? = Bundle.main.bundleIdentifier) -> Bool {
        guard let currentDefault, !currentDefault.isEmpty else { return false }
        return !isBrowBro(bundleID: currentDefault, current: me)
    }

    static var capturedPriorDefault: String? {
        UserDefaults.standard.string(forKey: priorDefaultKey)
    }

    /// Ask macOS to make BrowBro the default handler for http(s).
    /// macOS may show a confirmation prompt — that's expected.
    static func setAsDefault() async throws {
        capturePriorDefault()
        let me = Bundle.main.bundleURL
        try await NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "https")
        try await NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "http")
    }

    /// The reversible half of the takeover: hand the default back to whatever
    /// browser held it before BrowBro. The capture is kept so the status can
    /// still name it.
    static func restorePriorDefault() async throws {
        guard
            let id = capturedPriorDefault,
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        else { return }
        try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "https")
        try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "http")
    }

    /// Display name + icon for the captured prior default (for onboarding and
    /// the restore row).
    static func priorDefaultApp() -> (name: String, appURL: URL)? {
        guard
            let id = capturedPriorDefault,
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        else { return nil }
        let name = FileManager.default.displayName(atPath: appURL.path)
            .replacingOccurrences(of: ".app", with: "")
        return (name, appURL)
    }
}
