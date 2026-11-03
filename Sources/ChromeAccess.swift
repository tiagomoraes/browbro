import AppKit
import Darwin
import os

private let accessLog = Logger(subsystem: "cloud.tiagomoraes.browbro", category: "access")

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

    /// The one security-scoped URL this process is accessing: the resolved
    /// bookmark, or what the open panel returned (which may be the `Google`
    /// parent of `scopedFolder`). See `hold(_:)`.
    private static var accessedURL: URL?

    /// How a grant attempt ended, for Settings to explain.
    enum GrantResult: Equatable {
        case granted
        case cancelled
        /// The user picked a folder that isn't Chrome's user-data folder
        /// (e.g. "Chrome Beta"); carries its name for the message.
        case wrongFolder(name: String)
        /// The right folder, but `Local State` still can't be read.
        case unreadable
    }

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

    /// Where stable Google Chrome keeps its user data — the only folder whose
    /// profile directories `--profile-directory` resolves against.
    nonisolated static func chromeUserDataFolder(home: URL) -> URL {
        home.appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
    }

    static var chromeSupportFolder: URL {
        scopedFolder ?? chromeUserDataFolder(home: realHome)
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
        guard scopedFolder == nil else { return }
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            accessLog.debug("no Chrome folder bookmark to restore")
            return
        }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale)
            // Earlier builds accepted any folder holding a Local State; a saved
            // grant of "Chrome Beta" must not keep feeding stable Chrome.
            guard isChromeUserDataFolder(url, home: realHome) else {
                accessLog.error("dropping Chrome folder bookmark that isn't Chrome's user-data folder")
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return
            }
            // Adopt the folder either way so this runs once per session: a
            // refused scope simply leaves Local State unreadable, and Settings
            // offers the grant again.
            scopedFolder = url
            if url.startAccessingSecurityScopedResource() {
                hold(url)
                accessLog.info("restored Chrome folder access from bookmark")
            } else {
                accessLog.info("Chrome folder bookmark resolved, but no security scope was granted")
            }
            if stale { saveBookmark(for: url) }
        } catch {
            accessLog.error("couldn't resolve Chrome folder bookmark: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Ask the user to grant access to *just* the Chrome folder via an open panel.
    @discardableResult
    static func requestAccess() -> GrantResult {
        let panel = NSOpenPanel()
        panel.message = "Select your Google Chrome folder so BrowBro can read your profile list. This grants access to only this folder — not your whole disk."
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        // Open at "…/Application Support/Google" so the "Chrome" folder is right there to pick.
        // The open panel is out-of-process, so it can see the real home even in the sandbox.
        panel.directoryURL = chromeUserDataFolder(home: realHome).deletingLastPathComponent()

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return .cancelled }

        // The panel's grant is a security scope on exactly what was picked;
        // it must be balanced with a stop whether or not we keep it.
        let started = url.startAccessingSecurityScopedResource()
        guard let folder = resolveChromeFolder(from: url) else {
            if started { url.stopAccessingSecurityScopedResource() }
            accessLog.notice("refused Chrome folder grant: \(url.path, privacy: .private(mask: .hash)) is not Chrome's user-data folder")
            return .wrongFolder(name: url.lastPathComponent)
        }
        if started { hold(url) }
        scopedFolder = folder
        saveBookmark(for: folder)
        return canReadLocalState() ? .granted : .unreadable
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

    /// The picked folder if it *is* Chrome's user-data folder, or its `Chrome`
    /// child if the user picked the `Google` parent. Nothing else qualifies —
    /// notably not "Chrome Beta" / "Chrome Canary", siblings right there in the
    /// panel's start folder: their profile directories would be launched in
    /// stable Chrome, which silently creates empty profiles with those names.
    private static func resolveChromeFolder(from url: URL) -> URL? {
        [url, url.appendingPathComponent("Chrome", isDirectory: true)]
            .first { isChromeUserDataFolder($0, home: realHome) }
    }

    /// Whether `url` names stable Chrome's user-data folder under `home`.
    /// Compares the literal standardized paths, then symlink-resolved ones (a
    /// relocated home), so it holds inside the sandbox where resolution may not
    /// be able to see every parent directory.
    nonisolated static func isChromeUserDataFolder(_ url: URL, home: URL) -> Bool {
        let expected = chromeUserDataFolder(home: home)
        if url.standardizedFileURL.path == expected.standardizedFileURL.path { return true }
        return url.standardizedFileURL.resolvingSymlinksInPath().path
            == expected.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// Keep exactly one security scope open — the newest. Every successful
    /// `startAccessingSecurityScopedResource` needs a matching stop, or each
    /// re-grant leaks a sandbox extension for the life of the process.
    private static func hold(_ url: URL) {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = url
    }

    /// Persist the grant. The sandbox only has
    /// `com.apple.security.files.user-selected.read-only`, so the bookmark must
    /// ask for read-only scope too — a read-write security-scoped bookmark of a
    /// read-only grant fails to create.
    private static func saveBookmark(for folder: URL) {
        do {
            let data = try folder.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } catch {
            // Unsandboxed: TCC still lets us read the real-home path next launch.
            // Sandboxed: the next launch will ask again. Either way, this session works.
            accessLog.error("couldn't save Chrome folder bookmark: \(error.localizedDescription, privacy: .public)")
        }
    }
}
