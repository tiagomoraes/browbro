import Foundation
import Observation
import os

private let linkLog = Logger(subsystem: "cloud.tiagomoraes.browbro", category: "links")

/// Holds the links BrowBro has received. Shared, observable, main-actor bound
/// (the Apple Event handler and the UI both touch it on the main thread).
@MainActor
@Observable
final class LinkStore {
    static let shared = LinkStore()
    private init() {}

    struct ReceivedLink: Identifiable {
        let id = UUID()
        let url: URL
        let at: Date
    }

    /// A link the user actually routed somewhere — feeds "Recent links" in the
    /// menu ("2m ago · opened in Chrome").
    struct RoutedLink: Identifiable {
        let id = UUID()
        let url: URL
        let at: Date
        let targetName: String
    }

    /// Most recently received link, if any.
    private(set) var lastURL: URL?
    private(set) var receivedAt: Date?
    /// Newest-first, capped.
    private(set) var history: [ReceivedLink] = []
    /// Links routed through the picker, newest-first, capped.
    private(set) var recents: [RoutedLink] = []

    func receive(_ url: URL) {
        let now = Date()
        lastURL = url
        receivedAt = now
        history.insert(ReceivedLink(url: url, at: now), at: 0)
        if history.count > 20 { history.removeLast() }
        // Host stays readable for debugging routing; the full URL (paths and
        // queries often carry tokens) is hashed, so repeats still correlate.
        linkLog.info("received URL: \(url.host() ?? "?", privacy: .public) \(url.absoluteString, privacy: .private(mask: .hash))")
    }

    func recordOpen(_ url: URL, in targetName: String) {
        recents.insert(RoutedLink(url: url, at: Date(), targetName: targetName), at: 0)
        if recents.count > 10 { recents.removeLast() }
    }
}
