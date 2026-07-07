import Foundation

/// Which browsers can open a Private Window from the command line, and how.
/// Only browsers listed here offer a Private Window variant — Safari has no
/// programmatic path, and a privacy feature that silently opened a normal
/// window would be worse than not offering one (ADR-0001).
enum PrivateWindow {
    struct Capability {
        /// The launch argument that opens a private window.
        let flag: String
        /// The browser's own word for it, used in the variant's display name
        /// ("Chrome Incognito", "Edge InPrivate", "Firefox Private").
        let dialect: String
    }

    /// Known private-capable browsers by bundle id.
    private static let table: [String: Capability] = [
        // Chromium family
        "com.google.Chrome": .init(flag: "--incognito", dialect: "Incognito"),
        "com.google.Chrome.beta": .init(flag: "--incognito", dialect: "Incognito"),
        "com.google.Chrome.canary": .init(flag: "--incognito", dialect: "Incognito"),
        "org.chromium.Chromium": .init(flag: "--incognito", dialect: "Incognito"),
        "com.brave.Browser": .init(flag: "--incognito", dialect: "Private"),
        "com.vivaldi.Vivaldi": .init(flag: "--incognito", dialect: "Private"),
        "com.microsoft.edgemac": .init(flag: "--inprivate", dialect: "InPrivate"),
        "com.operasoftware.Opera": .init(flag: "--private", dialect: "Private"),
        // Firefox family
        "org.mozilla.firefox": .init(flag: "--private-window", dialect: "Private"),
        "org.mozilla.firefoxdeveloperedition": .init(flag: "--private-window", dialect: "Private"),
        "org.mozilla.nightly": .init(flag: "--private-window", dialect: "Private"),
    ]

    static func capability(for bundleID: String) -> Capability? {
        table[bundleID]
    }
}
