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

    /// Open a URL by invoking the browser with launch flags (`--profile-directory`,
    /// `--incognito`, `--private-window`, …).
    ///
    /// Flags are only honored as process arguments — `NSWorkspace.open(urls:…)`
    /// drops them. These browsers dedupe to their running instance, so this
    /// opens the right window whether or not the browser is already open
    /// (verified live for Chrome and Firefox — ADR-0001).
    ///
    /// Direct (DMG/Homebrew) builds spawn the bundle executable. The Mac App
    /// Store sandbox forbids that, and NSWorkspace drops arguments for a sandboxed
    /// caller, so those builds go through the user-installed `LaunchHelper`.
    @MainActor
    @discardableResult
    static func open(_ url: URL, withBinaryOfAppAt appURL: URL, flags: [String]) -> Bool {
        #if APPSTORE
        return openViaHelper(url, appAt: appURL, flags: flags)
        #else
        return openViaProcess(url, appAt: appURL, flags: flags)
        #endif
    }

    /// Launch a resolved target (browser, Chrome profile, or a Private Window
    /// variant of either) with a URL.
    @MainActor
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

    #if APPSTORE
    /// Sandbox-legal launch. The flags travel through `LaunchHelper`; if it isn't
    /// installed yet, this is the moment it matters, so ask now. Declining still
    /// delivers the link — in the browser's ordinary window — rather than dropping it.
    @MainActor
    private static func openViaHelper(_ url: URL, appAt appURL: URL, flags: [String]) -> Bool {
        let arguments = flags + [url.absoluteString]
        if LaunchHelper.open(appAt: appURL, arguments: arguments) { return true }
        if LaunchHelper.install(), LaunchHelper.open(appAt: appURL, arguments: arguments) { return true }
        launchLog.info("no launch helper; opening \(appURL.lastPathComponent, privacy: .public) without flags")
        open(url, withAppAt: appURL)
        return false
    }
    #else
    /// Direct binary invocation. The binary comes from the bundle's
    /// CFBundleExecutable — Firefox's is `firefox`, Chrome's is `Google Chrome`.
    private static func openViaProcess(_ url: URL, appAt appURL: URL, flags: [String]) -> Bool {
        guard let binary = Bundle(url: appURL)?.executableURL else { return false }
        let process = Process()
        process.executableURL = binary
        process.arguments = flags + [url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            launchLog.error("process launch failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    #endif
}
