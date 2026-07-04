import Foundation

/// A single pickable destination: either a browser app, or a specific Chrome profile.
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
}
