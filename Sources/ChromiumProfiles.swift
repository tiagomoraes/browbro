import Foundation

/// A Chromium browser profile as shown in the picker and passed to `--profile-directory`.
struct ChromiumProfile: Identifiable, Hashable {
    let directory: String    // launch key: "Default", "Profile 1", …
    let name: String         // display name: "acaso"
    let email: String?       // user_name, e.g. "tiago.moraes@aca.so"
    let colorARGB: Int?      // profile_highlight_color, for the avatar swatch
    var id: String { directory }
}

/// Reads a Chromium browser's `Local State` JSON and returns its profiles.
@MainActor
enum ChromiumProfiles {
    static func localStateURL(for browser: any ChromiumBrowser) -> URL {
        // Routed through ChromiumAccess so a sandboxed build reads via the
        // security-scoped bookmark, not the container home.
        ChromiumAccess.supportFolder(for: browser).appendingPathComponent("Local State")
    }

    static func load(for browser: any ChromiumBrowser) -> [ChromiumProfile] {
        guard
            let data = try? Data(contentsOf: localStateURL(for: browser)),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        return browser.profiles(fromLocalState: root).sorted(by: order)
    }

    /// "Default" first, then "Profile N" numerically, then anything else by name.
    private static func order(_ a: ChromiumProfile, _ b: ChromiumProfile) -> Bool {
        func rank(_ dir: String) -> (Int, Int) {
            if dir == "Default" { return (0, 0) }
            if dir.hasPrefix("Profile "), let n = Int(dir.dropFirst(8)) { return (1, n) }
            return (2, 0)
        }
        let ra = rank(a.directory), rb = rank(b.directory)
        if ra.0 != rb.0 { return ra.0 < rb.0 }
        if ra.1 != rb.1 { return ra.1 < rb.1 }
        return a.name < b.name
    }
}
