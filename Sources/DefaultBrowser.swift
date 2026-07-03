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

    /// Remember the previous default the first time we're about to replace it.
    static func capturePriorDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: priorDefaultKey) == nil else { return }
        if let id = currentBundleID(), id != Bundle.main.bundleIdentifier {
            defaults.set(id, forKey: priorDefaultKey)
        }
    }

    static var capturedPriorDefault: String? {
        UserDefaults.standard.string(forKey: priorDefaultKey)
    }

    /// Ask macOS to make BrowBro the default handler for http(s).
    /// macOS may show a confirmation prompt — that's expected.
    static func setAsDefault() async throws {
        capturePriorDefaultIfNeeded()
        let me = Bundle.main.bundleURL
        try await NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "https")
        try await NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "http")
    }
}
