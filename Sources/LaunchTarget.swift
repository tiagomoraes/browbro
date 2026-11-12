import Foundation

/// A single pickable destination: a browser app, a specific Chromium browser
/// profile, or a Private Window variant of either.
struct LaunchTarget: Identifiable, Hashable {
    enum Kind: Hashable {
        case browser
        case chromiumProfile(directory: String)
    }

    let id: String
    let name: String
    let subtitle: String?     // email for Chromium profiles, nil for plain browsers
    let appURL: URL           // browser app bundle to launch
    let bundleID: String
    let kind: Kind
    let colorARGB: Int?       // Chromium profile highlight color, else nil
    var privateFlag: String? = nil  // launch argument for a Private Window variant, else nil

    var isPrivate: Bool { privateFlag != nil }
}
