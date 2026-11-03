import Foundation

/// Which URLs BrowBro is willing to hand to a browser.
///
/// The URL ends up on the browser's argument list (`BrowserLauncher`), so this is
/// a security boundary, not a nicety: `URL(string:)` happily parses
/// `--gpu-launcher=/x` as a *relative* URL, and on argv that is a Chromium switch.
/// Only absolute http(s) links (what BrowBro is registered for) and file URLs
/// (local `.html` documents opened through `CFBundleDocumentTypes`) pass; their
/// `absoluteString` always starts with the scheme, so it can never read as a flag.
enum LinkPolicy {
    static let allowedSchemes: Set<String> = ["http", "https", "file"]

    /// True if `url` may be routed to a browser. Schemes compare
    /// case-insensitively (`HTTPS://` is still https).
    static func isRoutable(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return allowedSchemes.contains(scheme)
    }
}
