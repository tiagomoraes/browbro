import AppKit

/// Discovers the set of launch targets: installed browsers + Chromium browser profiles.
enum TargetDiscovery {
    private static let probe = URL(string: "https://example.com")!

    /// Every app registered to handle http(s), except BrowBro itself.
    static func browsers() -> [LaunchTarget] {
        let me = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        var result: [LaunchTarget] = []
        for appURL in NSWorkspace.shared.urlsForApplications(toOpen: probe) {
            guard let bundleID = Bundle(url: appURL)?.bundleIdentifier, bundleID != me else { continue }
            guard seen.insert(bundleID).inserted else { continue }
            let name = FileManager.default.displayName(atPath: appURL.path)
                .replacingOccurrences(of: ".app", with: "")
            result.append(LaunchTarget(id: "app:\(bundleID)", name: name, subtitle: nil,
                                       appURL: appURL, bundleID: bundleID,
                                       kind: .browser, colorARGB: nil))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Profiles of every installed Chromium browser whose data is readable.
    /// (Reading Local State is gated by macOS TCC; a browser contributes []
    /// until access is granted.)
    @MainActor
    static func chromiumProfiles() -> [LaunchTarget] {
        ChromiumBrowsers.all.flatMap { browser -> [LaunchTarget] in
            guard let appURL = browser.appURL else { return [] }
            return ChromiumProfiles.load(for: browser).map { p in
                LaunchTarget(id: "\(browser.key):\(p.directory)", name: p.name, subtitle: p.email,
                             appURL: appURL, bundleID: browser.bundleID,
                             kind: .chromiumProfile(directory: p.directory), colorARGB: p.colorARGB)
            }
        }
    }

    /// Private Window variants of opted-in base targets. Derived, never
    /// persisted: they exist only while the master switch is on and the base
    /// target is opted in, so toggling off or uninstalling the browser removes
    /// them and saved ids dangle harmlessly (ADR-0001).
    static func privateVariants(of bases: [LaunchTarget]) -> [LaunchTarget] {
        guard Preferences.privateWindowsEnabled else { return [] }
        let enabled = Set(Preferences.privateEnabledTargets)
        return bases.compactMap { base in
            guard enabled.contains(base.id),
                  let capability = PrivateWindow.capability(for: base.bundleID) else { return nil }
            return LaunchTarget(id: "private:\(base.id)",
                                name: "\(base.name) \(capability.dialect)",
                                subtitle: base.subtitle,
                                appURL: base.appURL,
                                bundleID: base.bundleID,
                                kind: base.kind,
                                colorARGB: base.colorARGB,
                                privateFlag: capability.flag)
        }
    }

    @MainActor
    static func all() -> [LaunchTarget] {
        let bases = browsers() + chromiumProfiles()
        return bases + privateVariants(of: bases)
    }
}
