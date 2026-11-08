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

    /// Shown when BrowBro still isn't the default after asking. macOS refuses
    /// silently for builds it can't verify (ad-hoc / locally signed), and also
    /// lands here if the user declined the confirmation prompt.
    static let notDefaultMessage = "BrowBro still isn't the default. If macOS didn't ask you to confirm, it refused the request — common with locally built copies. You can choose BrowBro in System Settings → Desktop & Dock → Default web browser."

    /// `setAsDefault`, then report the outcome: nil once BrowBro is the default,
    /// otherwise a message for the UI.
    static func setAsDefaultReportingFailure() async -> String? {
        do {
            try await setAsDefault()
        } catch let error as CocoaError where error.code == .userCancelled {
            return nil
        } catch {
            return "macOS refused to change the default browser (\(error.localizedDescription)). You can choose BrowBro in System Settings → Desktop & Dock → Default web browser."
        }
        return isBrowBro ? nil : notDefaultMessage
    }

    /// Desktop & Dock, where the Default web browser menu lives.
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
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
