import Foundation

/// A Chrome profile as shown in the picker and passed to `--profile-directory`.
struct ChromeProfile: Identifiable, Hashable {
    let directory: String    // launch key: "Default", "Profile 1", …
    let name: String         // display name: "acaso"
    let email: String?       // user_name, e.g. "tiago.moraes@aca.so"
    let colorARGB: Int?      // profile_highlight_color, for the avatar swatch
    var id: String { directory }
}

/// Reads Chrome's `Local State` JSON and returns its profiles.
/// (Same structure verified against the real file; JSONSerialization keeps us
/// resilient to Chrome's large, frequently-changing schema.)
enum ChromeProfiles {
    static var localStateURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome/Local State")
    }

    static func load() -> [ChromeProfile] {
        guard
            let data = try? Data(contentsOf: localStateURL),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let profile = root["profile"] as? [String: Any],
            let cache = profile["info_cache"] as? [String: Any]
        else { return [] }

        let profiles: [ChromeProfile] = cache.compactMap { dir, raw in
            guard let info = raw as? [String: Any] else { return nil }
            let email = (info["user_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let color = info["profile_highlight_color"] as? Int
                ?? info["default_avatar_fill_color"] as? Int
            return ChromeProfile(
                directory: dir,
                name: (info["name"] as? String) ?? dir,
                email: email,
                colorARGB: color
            )
        }
        return profiles.sorted(by: order)
    }

    /// "Default" first, then "Profile N" numerically, then anything else by name.
    private static func order(_ a: ChromeProfile, _ b: ChromeProfile) -> Bool {
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
