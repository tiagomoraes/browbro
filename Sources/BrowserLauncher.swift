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

    /// Open a URL in Chrome routed to a specific profile directory (e.g. "Profile 1").
    ///
    /// We invoke the Chrome *binary* directly rather than `NSWorkspace.open`, because
    /// `--profile-directory` is only honored as a launch argument. Chrome dedupes to
    /// its running instance, so this opens a tab in the chosen profile whether or not
    /// Chrome is already open.
    @discardableResult
    static func openInChrome(_ url: URL, profileDirectory: String, chromeAppURL: URL? = nil) -> Bool {
        guard let appURL = chromeAppURL ?? self.chromeAppURL() else { return false }
        let binary = appURL.appendingPathComponent("Contents/MacOS/Google Chrome")
        let process = Process()
        process.executableURL = binary
        process.arguments = ["--profile-directory=\(profileDirectory)", url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }
}
