import SwiftUI
import AppKit

/// The dropdown shown when the BrowBro menu-bar glyph is clicked.
/// One job per zone, native macOS menu feel:
///   1. identity + health at a glance (wordmark + a single status pill)
///   2. the one action that matters when unhealthy (set-as-default CTA,
///      shown only when not default)
///   3. recent links — the useful content — as tappable rows (re-route)
///   4. app actions as plain menu items with muted shortcut hints
struct MenuDropdownView: View {
    @Environment(LinkStore.self) private var store
    @State private var isDefault = false
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1 — identity + health
            HStack(spacing: 10) {
                WordmarkView(size: 15)
                Spacer(minLength: 0)
                StatusPill(ok: isDefault, text: isDefault ? "Default" : "Not default")
            }
            .padding(EdgeInsets(top: 7, leading: 10, bottom: 8, trailing: 10))

            // 2 — the one CTA that matters, only when not default
            if !isDefault {
                Button(working ? "Setting…" : "Set as default browser") {
                    Task { await setDefault() }
                }
                .buttonStyle(BBButtonStyle(variant: .primary, size: .sm, fullWidth: true))
                .disabled(working)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }

            MenuSeparator()

            // 3 — recent links: the useful, actionable content
            SectionLabel(text: "Recent links")
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
            if store.recents.isEmpty {
                Text("Links you open will show up here.")
                    .font(BBFont.rowSub)
                    .foregroundStyle(BB.textTertiary)
                    .padding(EdgeInsets(top: 3, leading: 10, bottom: 8, trailing: 10))
            } else {
                ForEach(store.recents.prefix(3)) { recent in
                    MenuRow(
                        title: displayURL(recent.url),
                        subtitle: "\(timeAgo(recent.at)) · opened in \(recent.targetName)",
                        mono: true
                    ) {
                        reopen(recent.url)
                    }
                }
            }

            MenuSeparator()

            // 4 — app actions
            MenuRow(title: "Settings…", shortcut: "⌘,") {
                closeMenuWindow()
                SettingsWindowController.shared.show()
            }

            MenuRow(title: "Check for Updates…") {
                closeMenuWindow()
                UpdaterController.shared.checkForUpdates()
            }

            MenuRow(title: "Support BrowBro", shortcut: "♥") {
                closeMenuWindow()
                // Self-initiated opens route back through BrowBro without a
                // fresh willBecomeActive; snapshot the z-order here instead.
                SettingsWindowController.shared.captureOrderSnapshot()
                NSWorkspace.shared.open(BBLinks.supportPage)
            }

            MenuSeparator()

            MenuRow(title: "Quit BrowBro", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(4)
        .frame(width: 280)
        .onAppear { isDefault = DefaultBrowser.isBrowBro }
    }

    private func setDefault() async {
        working = true
        defer { working = false }
        try? await DefaultBrowser.setAsDefault()
        isDefault = DefaultBrowser.isBrowBro
    }

    /// Clicking a recent link re-routes it: the picker pops right back up.
    private func reopen(_ url: URL) {
        closeMenuWindow()
        PickerController.shared.present(for: url)
    }

    /// The MenuBarExtra window doesn't auto-close on custom actions.
    private func closeMenuWindow() {
        NSApp.keyWindow?.orderOut(nil)
    }

    private func displayURL(_ url: URL) -> String {
        var s = url.absoluteString
        for scheme in ["https://", "http://"] where s.hasPrefix(scheme) {
            s.removeFirst(scheme.count)
        }
        if s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private func timeAgo(_ date: Date) -> String {
        let s = max(0, Int(Date().timeIntervalSince(date)))
        if s < 8 { return "just now" }
        if s < 60 { return "\(s)s ago" }
        let m = s / 60
        if m < 60 { return "\(m)m ago" }
        let h = m / 60
        if h < 24 { return "\(h)h ago" }
        return "\(h / 24)d ago"
    }
}

/// A native-feeling menu item: full-row accent highlight on hover, white text,
/// optional subtitle and muted shortcut hint.
private struct MenuRow: View {
    let title: String
    var subtitle: String? = nil
    var mono = false
    var shortcut: String? = nil
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(mono ? BBFont.url : .system(size: 13))
                        .foregroundStyle(hovered ? BB.onAccent : BB.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let subtitle {
                        Text(subtitle)
                            .font(BBFont.caption)
                            .foregroundStyle(hovered ? Color.white.opacity(0.82) : BB.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if let shortcut {
                    Text(shortcut)
                        .font(BBFont.rowSub)
                        .foregroundStyle(hovered ? Color.white.opacity(0.8) : BB.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, subtitle == nil ? 5 : 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                hovered ? BB.accentFill : Color.clear,
                in: RoundedRectangle(cornerRadius: BB.radiusSM, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            hovered = inside
            (inside ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
    }
}

private struct MenuSeparator: View {
    var body: some View {
        BBDivider()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
    }
}
