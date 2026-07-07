import Foundation

/// A single pickable destination: a browser app, a specific Chrome profile,
/// or a Private Window variant of either.
struct LaunchTarget: Identifiable, Hashable {
    enum Kind: Hashable {
        case browser
        case chromeProfile(directory: String)
    }

    let id: String
    let name: String
    let subtitle: String?     // email for Chrome profiles, nil for plain browsers
    let appURL: URL           // browser app bundle to launch
    let bundleID: String
    let kind: Kind
    let colorARGB: Int?       // Chrome profile highlight color, else nil
    var privateFlag: String? = nil  // launch argument for a Private Window variant, else nil

    var isPrivate: Bool { privateFlag != nil }
}
