import AppKit

/// Gates access to Chrome's (TCC-protected) data folder and helps the user grant it —
/// scoped to just the Chrome folder, never Full Disk Access.
@MainActor
enum ChromeAccess {
    static var isChromeInstalled: Bool {
        BrowserLauncher.chromeAppURL() != nil
    }

    static var chromeSupportFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
    }

    /// True only if we can actually read Local State (i.e. access is granted).
    static func canReadLocalState() -> Bool {
        guard isChromeInstalled else { return false }
        return (try? Data(contentsOf: ChromeProfiles.localStateURL)) != nil
    }

    /// Ask the user to grant access to *just* the Chrome folder via an open panel.
    /// Returns true if Local State became readable afterwards.
    @discardableResult
    static func requestAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.message = "Select your Google Chrome folder so BrowBro can read your profile list. This grants access to only this folder — not your whole disk."
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        // Open at "…/Application Support/Google" so the "Chrome" folder is right there to pick.
        panel.directoryURL = chromeSupportFolder.deletingLastPathComponent()

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return false }

        _ = url.startAccessingSecurityScopedResource()
        return canReadLocalState()
    }

    /// Fallback only: Full Disk Access (broader). Used if scoped access is refused.
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
