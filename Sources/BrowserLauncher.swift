import AppKit

/// Opens URLs in browsers — including a specific Chrome profile.
enum BrowserLauncher {

    /// Open a URL in an arbitrary browser app bundle.
    static func open(_ url: URL, withAppAt appURL: URL, completion: ((Error?) -> Void)? = nil) {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, error in
            completion?(error)
        }
    }

    /// The Google Chrome app bundle, if installed.
    static func chromeAppURL() -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome")
    }

    /// Open a URL by invoking the browser's *binary* directly with launch flags.
    ///
    /// Flags like `--profile-directory` and `--incognito` are only honored as launch
    /// arguments — `NSWorkspace.open` can't deliver them to a running app. These
    /// browsers dedupe to their running instance, so this opens the right window
    /// whether or not the browser is already open (verified live for Chrome and
    /// Firefox — ADR-0001). The binary comes from the bundle's CFBundleExecutable.
    @discardableResult
    static func open(_ url: URL, withBinaryOfAppAt appURL: URL, flags: [String]) -> Bool {
        guard let binary = Bundle(url: appURL)?.executableURL else { return false }
        let process = Process()
        process.executableURL = binary
        process.arguments = flags + [url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }

    /// Launch a resolved target (browser, Chrome profile, or a Private Window
    /// variant of either) with a URL.
    static func launch(_ target: LaunchTarget, url: URL) {
        var flags: [String] = []
        if case .chromeProfile(let directory) = target.kind {
            flags.append("--profile-directory=\(directory)")
        }
        if let privateFlag = target.privateFlag {
            flags.append(privateFlag)
        }
        if flags.isEmpty {
            open(url, withAppAt: target.appURL)
        } else {
            open(url, withBinaryOfAppAt: target.appURL, flags: flags)
        }
    }
}
