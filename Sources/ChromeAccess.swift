import AppKit
import Darwin

/// Gates access to Chrome's (TCC-protected) data folder and helps the user grant it —
/// scoped to just the Chrome folder, never Full Disk Access.
///
/// The Mac App Store build runs in the App Sandbox, so `homeDirectoryForCurrentUser`
/// is the container, not the real home. Access therefore goes through:
///   1. a security-scoped bookmark of the folder the user picked in an open panel
///      (required in the sandbox; survives relaunch)
///   2. the real home directory reconstructed via `getpwuid` (enough outside the
///      sandbox once TCC has been granted)
@MainActor
enum ChromeAccess {
    private static let bookmarkKey = "chromeSupportFolderBookmark"

    /// The Chrome data folder we currently have access to, if a bookmark was
    /// resolved this session. Prefer this over reconstructing the path.
    private static var scopedFolder: URL?

    static var isChromeInstalled: Bool {
        BrowserLauncher.chromeAppURL() != nil
    }

    /// The user's real home directory, even when this process is sandboxed.
    /// `FileManager.homeDirectoryForCurrentUser` / `$HOME` point at the container.
    static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var chromeSupportFolder: URL {
        scopedFolder
            ?? realHome.appendingPathComponent(
                "Library/Application Support/Google/Chrome", isDirectory: true)
    }

    /// True only if we can actually read Local State (i.e. access is granted).
    static func canReadLocalState() -> Bool {
        guard isChromeInstalled else { return false }
        restorePersistedAccess()
        return (try? Data(contentsOf: ChromeProfiles.localStateURL)) != nil
    }

    /// Re-establish sandbox access from a previously saved bookmark. Safe to call
    /// more than once; no-ops when a scoped folder is already live or no bookmark
    /// exists. Unsandboxed launches still work off the real-home path if this
    /// fails (TCC is independent of bookmarks).
    static func restorePersistedAccess() {
        guard scopedFolder == nil,
              let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale)
            guard url.startAccessingSecurityScopedResource() else { return }
            scopedFolder = url
            if stale { persist(url) }
        } catch {
            return
        }
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
        // The open panel is out-of-process, so it can see the real home even in the sandbox.
        panel.directoryURL = chromeSupportFolder.deletingLastPathComponent()

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return false }

        _ = url.startAccessingSecurityScopedResource()
        guard let folder = resolveChromeFolder(from: url) else { return false }
        persist(folder)
        return canReadLocalState()
    }

    /// Fallback only: Full Disk Access (broader). Used if scoped access is refused.
    /// Hidden from the Mac App Store binary — review treats FDA as overreach when
    /// an open panel already covers the Chrome folder.
    static func openFullDiskAccessSettings() {
        #if APPSTORE
        return
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    /// The selected URL is the Chrome folder if it contains `Local State`, or
    /// the `Chrome` child if the user picked the `Google` parent.
    private static func resolveChromeFolder(from url: URL) -> URL? {
        let fm = FileManager.default
        if fm.isReadableFile(atPath: url.appendingPathComponent("Local State").path) {
            return url
        }
        let nested = url.appendingPathComponent("Chrome", isDirectory: true)
        if fm.isReadableFile(atPath: nested.appendingPathComponent("Local State").path) {
            return nested
        }
        return nil
    }

    private static func persist(_ folder: URL) {
        if let previous = scopedFolder, previous != folder {
            previous.stopAccessingSecurityScopedResource()
        }
        scopedFolder = folder
        do {
            let data = try folder.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } catch {
            // Unsandboxed: TCC still lets us read the real-home path next launch.
            // Sandboxed: the next launch will ask again. Either way, this session works.
        }
    }
}
