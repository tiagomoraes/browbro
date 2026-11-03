#if APPSTORE
import AppKit
import os

private let helperLog = Logger(subsystem: "cloud.tiagomoraes.browbro", category: "launch")

/// Opens a browser with launch flags from inside the App Sandbox.
///
/// A sandboxed app cannot pass arguments to another app: NSWorkspace ignores
/// `OpenConfiguration.arguments` when the caller is sandboxed (NSWorkspace.h), so a
/// Chrome profile row opened Chrome's profile chooser and a Private row opened a
/// normal window. macOS's sanctioned way out is a script the *user* places in the
/// app's Application Scripts folder: `NSUserUnixTask` runs it outside the sandbox.
/// The app can read that folder but not write it, so the user saves the script
/// there once, through a save panel.
///
/// The script does one thing — `open -n -a <browser> --args <flags> <url>` — the
/// same call the direct build makes through `Process`.
@MainActor
enum LaunchHelper {
    static let fileName = "browbro-launch"

    /// Bump with any change to `script`; an older copy then reads as not installed.
    private static let version = 1

    static var script: String {
        """
        #!/bin/sh
        # BrowBro launch helper v\(version)
        #
        # The App Sandbox can't pass launch flags to another app, so BrowBro runs this
        # to open a browser in a Chrome profile or a private window:
        #   browbro-launch <path to browser .app> <flags…> <url>
        app="$1"
        shift
        exec /usr/bin/open -n -a "$app" --args "$@"

        """
    }

    /// `~/Library/Application Scripts/cloud.tiagomoraes.browbro`. macOS creates it for
    /// a sandboxed app; the app may read it but only the user may put files in it.
    static var directory: URL? {
        try? FileManager.default.url(
            for: .applicationScriptsDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
    }

    private static var scriptURL: URL? {
        directory?.appendingPathComponent(fileName, isDirectory: false)
    }

    static var isInstalled: Bool {
        guard let url = scriptURL,
              FileManager.default.isExecutableFile(atPath: url.path),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return text.contains("BrowBro launch helper v\(version)")
    }

    /// Ask the user to save the helper into the Application Scripts folder.
    /// Returns true once it is installed and runnable.
    @discardableResult
    static func install() -> Bool {
        guard let directory else { return false }
        let panel = NSSavePanel()
        panel.title = "Install BrowBro’s launch helper"
        panel.message = "To open links in a Chrome profile or a private window, BrowBro needs to pass a flag to your browser — something macOS doesn’t allow App Store apps to do on their own. Save this small script here once and BrowBro can. It only ever runs “open -a <browser>”."
        panel.prompt = "Install"
        panel.directoryURL = directory
        panel.nameFieldStringValue = fileName
        panel.canCreateDirectories = false

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return false }

        // NSUserUnixTask only runs scripts from this exact folder, under the name we look for.
        guard url.deletingLastPathComponent().resolvingSymlinksInPath().path
                == directory.resolvingSymlinksInPath().path,
              url.lastPathComponent == fileName else {
            let alert = NSAlert()
            alert.messageText = "Save the helper in BrowBro’s scripts folder"
            alert.informativeText = "macOS only lets BrowBro run it from \(directory.path), named “\(fileName)”. Try again and keep the folder and name the panel suggests."
            alert.runModal()
            return false
        }

        do {
            // Not atomic: the panel grants this one file, not a temp file beside it.
            try script.write(to: url, atomically: false, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        } catch {
            helperLog.error("helper install failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
        return isInstalled
    }

    /// Run the helper. Returns false when it isn't installed, so the caller can ask.
    static func open(appAt appURL: URL, arguments: [String]) -> Bool {
        guard isInstalled, let url = scriptURL else { return false }
        do {
            let task = try NSUserUnixTask(url: url)
            helperLog.info("helper launch \(appURL.lastPathComponent, privacy: .public) flags=\(arguments.dropLast().joined(separator: " "), privacy: .public)")
            task.execute(withArguments: [appURL.path] + arguments) { error in
                if let error {
                    helperLog.error("helper launch failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            return true
        } catch {
            helperLog.error("helper unusable: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
#endif
