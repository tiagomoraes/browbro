import Foundation

/// Google Chrome. Uses the shared Chromium profile parsing and launch flags.
struct ChromeBrowser: ChromiumBrowser {
    let key = "chrome"
    let displayName = "Chrome"
    let appName = "Google Chrome"
    let bundleID = "com.google.Chrome"
    let supportFolderPath = "Library/Application Support/Google/Chrome"
    // Predates the per-browser keys; kept so existing grants survive the update.
    let bookmarkKey = "chromeSupportFolderBookmark"
    let privateWindow: PrivateWindow.Capability? = .init(flag: "--incognito", dialect: "Incognito")
}
