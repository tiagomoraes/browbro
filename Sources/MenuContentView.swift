import SwiftUI

/// The menu-bar popover for the risky-slice prototype. Proves two things:
///   1. links are being received (shows the last URL + history)
///   2. BrowBro can read / become the default browser
struct MenuContentView: View {
    @Environment(LinkStore.self) private var store
    @State private var defaultStatus = "Checking…"
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BrowBro").font(.headline)

            GroupBox("Last received link") {
                VStack(alignment: .leading, spacing: 4) {
                    if let url = store.lastURL {
                        Text(url.absoluteString)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(3)
                        if let at = store.receivedAt {
                            Text(at.formatted(date: .omitted, time: .standard))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Waiting for a link…\nTest it:  open -a BrowBro \"https://example.com/it-works\"")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Default browser") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(defaultStatus).font(.callout)
                    Button(working ? "Setting…" : "Set BrowBro as default browser") {
                        Task { await setDefault() }
                    }
                    .disabled(working)
                    if let prior = DefaultBrowser.capturedPriorDefault {
                        Text("Prior default captured: \(prior)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !store.history.isEmpty {
                GroupBox("Recent") {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(store.history.prefix(5)) { item in
                            Text(item.url.absoluteString)
                                .font(.caption).lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()
            Button("Quit BrowBro") { NSApplication.shared.terminate(nil) }
        }
        .padding(14)
        .frame(width: 380)
        .task { refreshDefaultStatus() }
    }

    private func refreshDefaultStatus() {
        if DefaultBrowser.isBrowBro {
            defaultStatus = "✅ BrowBro is the default browser"
        } else if let id = DefaultBrowser.currentBundleID() {
            defaultStatus = "Current default: \(id)"
        } else {
            defaultStatus = "Unknown"
        }
    }

    private func setDefault() async {
        working = true
        defer { working = false }
        do {
            try await DefaultBrowser.setAsDefault()
            refreshDefaultStatus()
        } catch {
            defaultStatus = "Failed: \(error.localizedDescription)"
        }
    }
}
