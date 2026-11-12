import Foundation

/// Brave Origin, Brave's stripped-down build. Its `Local State` uses the
/// standard Chromium `profile.info_cache` layout (verified against a real
/// install), so profile parsing and launch flags stay the shared defaults;
/// override them here if Brave Origin starts to diverge.
struct BraveOriginBrowser: ChromiumBrowser {
    let key = "brave-origin"
    let displayName = "Brave Origin"
    let bundleID = "com.brave.Browser.origin"
    // Brave keeps its channels side by side under "BraveSoftware"
    // (Brave-Browser, Brave-Browser-Beta, …, Brave-Origin).
    let supportFolderPath = "Library/Application Support/BraveSoftware/Brave-Origin"
    // Same private-window flag and name as regular Brave (BraveBrowser).
    let privateWindow: PrivateWindow.Capability? = .init(flag: "--incognito", dialect: "Private")
}
