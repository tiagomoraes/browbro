import Foundation

/// A user-defined match on a link that always opens it in a chosen Launch Target,
/// skipping the Picker. First enabled match in `RuleStore` order wins.
struct URLRule: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    /// Host (and optional path) to match, e.g. `meet.google.com` or `github.com/org`.
    /// A pasted full URL is fine — the scheme is ignored.
    var pattern: String
    var targetID: String
    var enabled: Bool

    init(id: UUID = UUID(), pattern: String, targetID: String, enabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.targetID = targetID
        self.enabled = enabled
    }

    /// Host match: the URL's host equals the pattern host, or is a subdomain of it.
    /// A leading `*.` or `www.` is ignored; a `:port` must match exactly.
    /// If the pattern includes a path, the URL path must have that prefix too.
    func matches(_ url: URL) -> Bool {
        guard enabled else { return false }
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let stripped = Self.stripScheme(trimmed)
        let parts = stripped.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard let hostPart = parts.first, !hostPart.isEmpty else { return false }
        var patternHost = String(hostPart).lowercased()
        let patternPath = parts.count > 1 ? "/" + parts[1] : nil

        // "*.example.com" reads as "example.com" — subdomains match anyway.
        if patternHost.hasPrefix("*.") { patternHost.removeFirst(2) }
        // Optional port: "localhost:3000" must match that port exactly.
        var patternPort: Int?
        if let colon = patternHost.lastIndex(of: ":") {
            guard let port = Int(patternHost[patternHost.index(after: colon)...]) else { return false }
            patternPort = port
            patternHost = String(patternHost[..<colon])
        }
        patternHost = Self.stripWWW(patternHost)
        guard !patternHost.isEmpty else { return false }

        guard let rawHost = url.host?.lowercased() else { return false }
        let urlHost = Self.stripWWW(rawHost)
        // Exact host, or a subdomain of a dotted host. A bare TLD like "com"
        // must not match every .com site. "www." is ignored on both sides.
        let hostOK = urlHost == patternHost
            || (patternHost.contains(".") && urlHost.hasSuffix("." + patternHost))
        guard hostOK else { return false }

        if let patternPort {
            let defaultPort = url.scheme?.lowercased() == "http" ? 80 : 443
            guard (url.port ?? defaultPort) == patternPort else { return false }
        }

        if let patternPath {
            let path = url.path.isEmpty ? "/" : url.path
            let needle = patternPath.lowercased()
            let haystack = path.lowercased()
            return haystack == needle || haystack.hasPrefix(needle.hasSuffix("/") ? needle : needle + "/")
        }
        return true
    }

    private static func stripWWW(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func stripScheme(_ raw: String) -> String {
        var s = raw
        for prefix in ["https://", "http://"] where s.lowercased().hasPrefix(prefix) {
            s.removeFirst(prefix.count)
            break
        }
        if let q = s.firstIndex(of: "?") { s = String(s[..<q]) }
        if let h = s.firstIndex(of: "#") { s = String(s[..<h]) }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}
