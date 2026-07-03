import Foundation
import Observation
import os

private let linkLog = Logger(subsystem: "so.aca.browbro", category: "links")

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

    /// Most recently received link, if any.
    private(set) var lastURL: URL?
    private(set) var receivedAt: Date?
    /// Newest-first, capped.
    private(set) var history: [ReceivedLink] = []

    func receive(_ url: URL) {
        let now = Date()
        lastURL = url
        receivedAt = now
        history.insert(ReceivedLink(url: url, at: now), at: 0)
        if history.count > 20 { history.removeLast() }
        linkLog.info("received URL: \(url.absoluteString, privacy: .public)")
    }
}
