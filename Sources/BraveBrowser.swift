import Foundation

/// Brave (the regular release channel). Chromium's standard `Local State`
/// layout, so profile parsing and launch flags stay the shared defaults;
/// override them here if Brave starts to diverge.
struct BraveBrowser: ChromiumBrowser {
    let key = "brave"
    let displayName = "Brave"
    let appName = "Brave Browser"
    let bundleID = "com.brave.Browser"
    // Brave keeps its channels side by side under "BraveSoftware"
    // (Brave-Browser, Brave-Browser-Beta, …, Brave-Origin).
    let supportFolderPath = "Library/Application Support/BraveSoftware/Brave-Browser"
    // Brave launches private windows with Chromium's `--incognito` flag but
    // calls them "Private".
    let privateWindow: PrivateWindow.Capability? = .init(flag: "--incognito", dialect: "Private")
}
