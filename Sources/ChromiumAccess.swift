import AppKit
import Darwin

/// Gates access to a Chromium browser's (TCC-protected) data folder and helps
/// the user grant it — scoped to just that folder, never Full Disk Access.
///
/// The Mac App Store build runs in the App Sandbox, so `homeDirectoryForCurrentUser`
/// is the container, not the real home. Access therefore goes through:
///   1. a security-scoped bookmark of the folder the user picked in an open panel
///      (required in the sandbox; survives relaunch), one per browser
///   2. the real home directory reconstructed via `getpwuid` (enough outside the
///      sandbox once TCC has been granted)
@MainActor
enum ChromiumAccess {
    /// Data folders we currently have access to, keyed by `ChromiumBrowser.key`,
    /// for bookmarks resolved this session. Prefer these over reconstructing the path.
    private static var scopedFolders: [String: URL] = [:]

    /// The user's real home directory, even when this process is sandboxed.
    /// `FileManager.homeDirectoryForCurrentUser` / `$HOME` point at the container.
    static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static func supportFolder(for browser: any ChromiumBrowser) -> URL {
        scopedFolders[browser.key]
            ?? realHome.appendingPathComponent(browser.supportFolderPath, isDirectory: true)
    }

    /// True only if we can actually read Local State (i.e. access is granted).
    static func canReadLocalState(for browser: any ChromiumBrowser) -> Bool {
        guard browser.isInstalled else { return false }
        restorePersistedAccess(for: browser)
        return (try? Data(contentsOf: ChromiumProfiles.localStateURL(for: browser))) != nil
    }

    /// Re-establish sandbox access for every supported browser.
    static func restorePersistedAccess() {
        ChromiumBrowsers.all.forEach(restorePersistedAccess(for:))
    }

    /// Re-establish sandbox access from a previously saved bookmark. Safe to call
    /// more than once; no-ops when a scoped folder is already live or no bookmark
    /// exists. Unsandboxed launches still work off the real-home path if this
    /// fails (TCC is independent of bookmarks).
    static func restorePersistedAccess(for browser: any ChromiumBrowser) {
        guard scopedFolders[browser.key] == nil,
              let data = UserDefaults.standard.data(forKey: browser.bookmarkKey) else { return }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale)
            guard url.startAccessingSecurityScopedResource() else { return }
            scopedFolders[browser.key] = url
            if stale { persist(url, for: browser) }
        } catch {
            return
        }
    }

    /// Ask the user to grant access to *just* the browser's data folder via an
    /// open panel. Returns true if Local State became readable afterwards.
    @discardableResult
    static func requestAccess(for browser: any ChromiumBrowser) -> Bool {
        let folderName = (browser.supportFolderPath as NSString).lastPathComponent
        let panel = NSOpenPanel()
        panel.message = "Select your \(browser.appName) folder (“\(folderName)”) so BrowBro can read your profile list. This grants access to only this folder — not your whole disk."
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        // Open at the parent (e.g. "…/Application Support/Google") so the data
        // folder is right there to pick. The open panel is out-of-process, so it
        // can see the real home even in the sandbox.
        panel.directoryURL = supportFolder(for: browser).deletingLastPathComponent()

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return false }

        _ = url.startAccessingSecurityScopedResource()
        guard let folder = resolveDataFolder(from: url, for: browser) else { return false }
        persist(folder, for: browser)
        return canReadLocalState(for: browser)
    }

    /// Fallback only: Full Disk Access (broader). Used if scoped access is refused.
    /// Hidden from the Mac App Store binary — review treats FDA as overreach when
    /// an open panel already covers the browser's folder.
    static func openFullDiskAccessSettings() {
        #if APPSTORE
        return
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    /// The selected URL is the data folder if it contains `Local State`, or its
    /// child (e.g. `Chrome`) if the user picked the vendor parent (e.g. `Google`).
    private static func resolveDataFolder(from url: URL, for browser: any ChromiumBrowser) -> URL? {
        let fm = FileManager.default
        if fm.isReadableFile(atPath: url.appendingPathComponent("Local State").path) {
            return url
        }
        let folderName = (browser.supportFolderPath as NSString).lastPathComponent
        let nested = url.appendingPathComponent(folderName, isDirectory: true)
        if fm.isReadableFile(atPath: nested.appendingPathComponent("Local State").path) {
            return nested
        }
        return nil
    }

    private static func persist(_ folder: URL, for browser: any ChromiumBrowser) {
        if let previous = scopedFolders[browser.key], previous != folder {
            previous.stopAccessingSecurityScopedResource()
        }
        scopedFolders[browser.key] = folder
        do {
            let data = try folder.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
            UserDefaults.standard.set(data, forKey: browser.bookmarkKey)
        } catch {
            // Unsandboxed: TCC still lets us read the real-home path next launch.
            // Sandboxed: the next launch will ask again. Either way, this session works.
        }
    }
}
