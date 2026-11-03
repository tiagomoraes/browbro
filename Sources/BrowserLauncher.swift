import AppKit
import os

private let launchLog = Logger(subsystem: "cloud.tiagomoraes.browbro", category: "launch")

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

    /// Open a URL in a browser with launch flags (`--profile-directory`,
    /// `--incognito`, `--private-window`, …).
    ///
    /// Flags are only honored as process arguments — `NSWorkspace.open(urls:…)`
    /// drops them — so this asks Launch Services to start the app with
    /// `OpenConfiguration.arguments`. `arguments` is ignored when opening URLs,
    /// so the URL goes on the argument list too, and a new instance is requested
    /// so a running browser actually receives them: Chromium and Firefox hand
    /// the arguments to their existing process and exit (ADR-0001).
    ///
    /// Both builds launch this way. The Mac App Store sandbox forbids spawning
    /// another app's binary, and even where it's allowed, a `Process()` child
    /// is the wrong shape: a cold-started browser would be BrowBro's child, so
    /// macOS would attribute its camera / microphone prompts to BrowBro, and it
    /// would inherit BrowBro's environment. Launch Services makes it a peer.
    static func open(_ url: URL, withAppAt appURL: URL, arguments flags: [String]) {
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = flags + [url.absoluteString]
        config.activates = true
        config.createsNewApplicationInstance = true
        launchLog.info("workspace launch \(appURL.lastPathComponent, privacy: .public) flags=\(flags.joined(separator: " "), privacy: .public)")
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if let error {
                launchLog.error("workspace launch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Launch a resolved target (browser, Chrome profile, or a Private Window
    /// variant of either) with a URL.
    static func launch(_ target: LaunchTarget, url: URL) {
        // Last line of defense: the URL is about to become an argv entry.
        // Entry points already filter (AppDelegate, PickerController).
        guard LinkPolicy.isRoutable(url) else {
            launchLog.error("refusing to launch URL with unsupported scheme \(url.scheme ?? "none", privacy: .public)")
            return
        }
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
            open(url, withAppAt: target.appURL, arguments: flags)
        }
    }
}
