import AppKit

/// A Chromium-based browser whose profiles BrowBro lists as their own Launch
/// Targets.
///
/// This file holds only what the Chromium family shares — the `Local State` →
/// `profile.info_cache` layout and the `--profile-directory` launch flag — as
/// default implementations. Each browser lives in its own file
/// (`ChromeBrowser.swift`, `BraveBrowser.swift`, `BraveOriginBrowser.swift`) with its identity and
/// anything it does differently; overriding a requirement there replaces the
/// shared behavior for that browser only.
protocol ChromiumBrowser: Sendable {
    /// Stable key, used as the target id prefix (`<key>:<profile dir>`) and in
    /// the persisted bookmark key. Never change it for a shipped browser —
    /// saved picker order, hidden and default targets reference it.
    var key: String { get }
    /// Short name for Settings and target subtitles ("Chrome", "Brave Origin").
    var displayName: String { get }
    /// Full product name for the access prompt ("Google Chrome").
    var appName: String { get }
    var bundleID: String { get }
    /// The browser's user-data folder, relative to the real home directory.
    var supportFolderPath: String { get }
    /// UserDefaults key for the sandbox security-scoped bookmark of that folder.
    var bookmarkKey: String { get }
    /// How this browser opens a Private Window, or nil if BrowBro shouldn't offer one.
    var privateWindow: PrivateWindow.Capability? { get }

    /// Profiles from the decoded `Local State` JSON, in any order.
    func profiles(fromLocalState root: [String: Any]) -> [ChromiumProfile]
    /// Launch arguments that open the given profile.
    func launchFlags(profileDirectory: String) -> [String]
}

// MARK: - Shared Chromium behavior

extension ChromiumBrowser {
    var appName: String { displayName }

    var bookmarkKey: String { "\(key)SupportFolderBookmark" }

    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    var isInstalled: Bool { appURL != nil }

    /// Chromium's schema: `profile.info_cache` maps the profile directory to its
    /// info. (JSONSerialization keeps us resilient to the large, frequently-
    /// changing schema.)
    func profiles(fromLocalState root: [String: Any]) -> [ChromiumProfile] {
        guard
            let profile = root["profile"] as? [String: Any],
            let cache = profile["info_cache"] as? [String: Any]
        else { return [] }

        return cache.compactMap { dir, raw in
            guard let info = raw as? [String: Any] else { return nil }
            let email = (info["user_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let color = info["profile_highlight_color"] as? Int
                ?? info["default_avatar_fill_color"] as? Int
            return ChromiumProfile(
                directory: dir,
                name: (info["name"] as? String) ?? dir,
                email: email,
                colorARGB: color
            )
        }
    }

    func launchFlags(profileDirectory: String) -> [String] {
        ["--profile-directory=\(profileDirectory)"]
    }
}

// MARK: - Registry

/// The supported Chromium browsers, in the order their profiles are listed.
/// Adding a browser = a new conforming type in its own file + one entry here.
enum ChromiumBrowsers {
    static let all: [any ChromiumBrowser] = [ChromeBrowser(), BraveBrowser(), BraveOriginBrowser()]

    static var installed: [any ChromiumBrowser] {
        all.filter(\.isInstalled)
    }

    static func browser(forBundleID bundleID: String) -> (any ChromiumBrowser)? {
        all.first { $0.bundleID == bundleID }
    }
}
