import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// BrowBro Settings: default-browser status with restore, Chrome-profile
/// access, the picker catalog (reorder + show/hide), and behavior toggles.
struct SettingsView: View {
    @State private var catalog = TargetCatalog.shared
    @State private var isDefault = DefaultBrowser.isBrowBro
    @State private var chromeAccess = false
    @State private var working = false

    @AppStorage(Preferences.rememberLastKey) private var rememberLast = false
    @AppStorage(Preferences.skipSingleKey) private var skipSingle = false
    @State private var launchAtLogin = false

    @State private var draggingID: String?

    var body: some View {
        VStack(spacing: 0) {
            titleHeader
            BBDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: BB.padPanel) {
                    defaultBrowserGroup
                    if ChromeAccess.isChromeInstalled {
                        chromeGroup
                    }
                    catalogGroup
                    behaviorGroup
                }
                .padding(BB.padPanel)
            }
        }
        .frame(width: 480)
        .frame(minHeight: 380, maxHeight: 560)
        .background(BB.surfaceRaised)
        // The window is full-size-content with a hidden system title; the view
        // owns the header (Settings.jsx draws its own), so claim the very top.
        .ignoresSafeArea(.container, edges: .top)
        .onAppear(perform: refresh)
    }

    /// The design's own window header: title beside the traffic lights, over a
    /// hairline. Replaces the system title text, which would overlap content.
    private var titleHeader: some View {
        HStack {
            Text("BrowBro Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BB.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.leading, 30)     // right after the close button (min/zoom are hidden)
        .frame(height: 28)         // vertically centered with it
        .padding(.bottom, 5)
    }

    private func refresh() {
        catalog.refresh()
        isDefault = DefaultBrowser.isBrowBro
        chromeAccess = ChromeAccess.canReadLocalState()
        launchAtLogin = LoginItem.isEnabled
    }

    // MARK: Default browser

    private var defaultBrowserGroup: some View {
        SettingsGroup(title: "Default browser") {
            SettingsRow(
                leading: {
                    Circle()
                        .fill(isDefault ? BB.success : BB.warning)
                        .frame(width: 8, height: 8)
                },
                label: isDefault ? "BrowBro is your default browser" : "BrowBro is not the default",
                description: isDefault
                    ? "New links route through the picker."
                    : "macOS opens links elsewhere until you switch.",
                trailing: {
                    if isDefault {
                        if DefaultBrowser.priorDefaultApp() != nil {
                            Button("Restore previous") {
                                Task {
                                    try? await DefaultBrowser.restorePriorDefault()
                                    isDefault = DefaultBrowser.isBrowBro
                                }
                            }
                            .buttonStyle(BBButtonStyle(variant: .secondary, size: .sm))
                        }
                    } else {
                        Button(working ? "Setting…" : "Set as default") {
                            Task {
                                working = true
                                defer { working = false }
                                try? await DefaultBrowser.setAsDefault()
                                isDefault = DefaultBrowser.isBrowBro
                            }
                        }
                        .buttonStyle(BBButtonStyle(variant: .primary, size: .sm))
                        .disabled(working)
                    }
                })
        }
    }

    // MARK: Chrome profiles

    private var chromeGroup: some View {
        SettingsGroup(title: "Chrome profiles") {
            SettingsRow(
                leading: {
                    Image(systemName: chromeAccess ? "checkmark.shield" : "shield")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(chromeAccess ? BB.success : BB.iconSecondary)
                },
                label: chromeAccess ? "Access granted" : "Grant access to Chrome profiles",
                description: chromeAccess
                    ? "BrowBro reads your Chrome profiles to route links per profile."
                    : "BrowBro needs to read Chrome's data folder to list your profiles.",
                trailing: {
                    if chromeAccess {
                        Button("Re-grant…") { grantChrome() }
                            .buttonStyle(BBButtonStyle(variant: .ghost, size: .sm))
                    } else {
                        Button("Grant access…") { grantChrome() }
                            .buttonStyle(BBButtonStyle(variant: .primary, size: .sm))
                    }
                })
        }
    }

    private func grantChrome() {
        _ = ChromeAccess.requestAccess()
        refresh()
    }

    // MARK: Shown in the picker

    private var catalogGroup: some View {
        let shownCount = catalog.visible.count
        let total = catalog.all.count
        return SettingsGroup(
            title: "Shown in the picker",
            hint: total > 1 ? "drag to reorder" : "\(shownCount) of \(total) shown"
        ) {
            if catalog.all.isEmpty {
                SettingsRow(label: "No targets yet",
                            description: "Detected browsers will appear here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(catalog.all.enumerated()), id: \.element.id) { index, target in
                        CatalogRow(
                            target: target,
                            hidden: catalog.hidden.contains(target.id),
                            isLast: index == catalog.all.count - 1,
                            onToggle: { catalog.toggleHidden(target.id) }
                        )
                        .opacity(draggingID == target.id ? 0.4 : 1)
                        .onDrag {
                            draggingID = target.id
                            return NSItemProvider(object: target.id as NSString)
                        }
                        .onDrop(of: [.plainText],
                                delegate: CatalogDropDelegate(targetID: target.id,
                                                              draggingID: $draggingID,
                                                              catalog: catalog))
                    }
                }
            }
        }
    }

    // MARK: Behavior

    private var behaviorGroup: some View {
        SettingsGroup(title: "Behavior") {
            SettingsRow(
                label: "Remember last used",
                description: "Pre-highlight whatever you picked last time.",
                trailing: { BBSwitch(isOn: $rememberLast) })
            BBDivider().padding(.leading, 12)
            SettingsRow(
                label: "Skip picker for a single target",
                description: "If only one browser is shown, just open it.",
                trailing: { BBSwitch(isOn: $skipSingle) })
            BBDivider().padding(.leading, 12)
            SettingsRow(
                label: "Launch at login",
                description: "Keep BrowBro ready so the picker is instant.",
                trailing: {
                    BBSwitch(isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            try? LoginItem.set(enabled: newValue)
                            launchAtLogin = LoginItem.isEnabled
                        }))
                })
        }
    }
}

// MARK: - Group + row building blocks (Settings.jsx Group/Row)

private struct SettingsGroup<Content: View>: View {
    let title: String
    var hint: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: title)
                Spacer()
                if let hint {
                    Text(hint)
                        .font(BBFont.caption)
                        .foregroundStyle(BB.textQuaternary)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(BB.surfaceSunken, in: RoundedRectangle(cornerRadius: BB.radiusMD, style: .continuous))
        }
    }
}

private struct SettingsRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    let label: String
    var description: String? = nil
    @ViewBuilder var trailing: Trailing

    init(@ViewBuilder leading: () -> Leading = { EmptyView() },
         label: String,
         description: String? = nil,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.leading = leading()
        self.label = label
        self.description = description
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BB.textPrimary)
                if let description {
                    Text(description)
                        .font(BBFont.rowSub)
                        .foregroundStyle(BB.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Catalog row (drag to reorder, switch to show/hide)

private struct CatalogRow: View {
    let target: LaunchTarget
    let hidden: Bool
    let isLast: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                GripDots()
                leading
                VStack(alignment: .leading, spacing: 1) {
                    Text(target.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BB.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(BBFont.caption)
                        .foregroundStyle(BB.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                BBSwitch(isOn: Binding(get: { !hidden }, set: { _ in onToggle() }))
            }
            .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 10))
            .opacity(hidden ? 0.55 : 1)

            if !isLast {
                BBDivider().padding(.leading, 12)
            }
        }
        .contentShape(Rectangle())
        .cursor(.openHand)   // drag to reorder
    }

    @ViewBuilder private var leading: some View {
        if case .chromeProfile = target.kind {
            ProfileSwatch(name: target.name, colorARGB: target.colorARGB, size: 22)
        } else {
            AppIconChip(appURL: target.appURL, size: 22)
        }
    }

    private var subtitle: String {
        if case .chromeProfile = target.kind {
            return target.subtitle.map { "Chrome · \($0)" } ?? "Chrome profile"
        }
        return "Web browser"
    }
}

/// Six-dot drag handle (grip-vertical).
private struct GripDots: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().frame(width: 2.8, height: 2.8)
                    }
                }
            }
        }
        .foregroundStyle(BB.iconSecondary)
        .frame(width: 16, height: 16)
    }
}

// MARK: - Window controller


/// Presents Settings in a manually managed window. Deliberately NOT a SwiftUI
/// `Settings` scene: for a MenuBarExtra-only app that scene is the app's only
/// window scene, and macOS sometimes presents it on its own when a clicked
/// link activates the app (reopen / state restoration) — leaving Settings
/// stranded behind the picker.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private override init() {}

    private var window: NSWindow?

    /// The window number (any app's) that sat directly in front of Settings
    /// the last time this app was about to be activated, plus when. Consumed
    /// by `restoreOrderAfterActivationRaise`.
    private var preRaiseNeighbor: (windowNumber: Int?, at: TimeInterval)?

    /// Snapshot the Settings window's place in the global z-order. Call at
    /// moments that precede a LaunchServices activation raise: the app's
    /// `willBecomeActive`, and right before the app opens a URL itself.
    func captureOrderSnapshot() {
        preRaiseNeighbor = nil
        guard let window, window.isVisible,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                as? [[String: Any]] else { return }
        var previous: Int?
        for w in info {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  let num = w[kCGWindowNumber as String] as? Int else { continue }
            if num == window.windowNumber {
                preRaiseNeighbor = (previous, ProcessInfo.processInfo.systemUptime)
                return
            }
            previous = num
        }
    }

    /// Undo the window server's activation raise. When another app opens a
    /// URL, LaunchServices activates BrowBro and the window server brings its
    /// front window — a background Settings window — above the sender. That
    /// raise happens below the NSWindow API (no ordering method is called), so
    /// it can't be blocked; instead, the URL handler calls this to put the
    /// window back under the neighbor captured just before activation. A user
    /// summoning Settings never routes a URL, so legitimate raises stay.
    func restoreOrderAfterActivationRaise() {
        guard let window, window.isVisible,
              let snap = preRaiseNeighbor,
              ProcessInfo.processInfo.systemUptime - snap.at < 3 else { return }
        preRaiseNeighbor = nil
        guard let neighbor = snap.windowNumber else { return }  // was frontmost anyway
        window.order(.below, relativeTo: neighbor)
    }

    /// Call when the user deliberately brings Settings forward (summoning it,
    /// clicking a link row inside it): a pending snapshot must not demote a
    /// window the user just chose to interact with.
    func invalidateOrderSnapshot() {
        preRaiseNeighbor = nil
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            // Explicitly full-size content with the system title hidden: the
            // view draws its own header (per the design), so the AppKit title
            // can never overlap the scrolled content.
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = "BrowBro Settings"   // Mission Control / accessibility
            window.isRestorable = false         // never resurrect behind the picker
            window.isReleasedWhenClosed = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        invalidateOrderSnapshot()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

/// Live reorder while dragging over rows.
private struct CatalogDropDelegate: DropDelegate {
    let targetID: String
    @Binding var draggingID: String?
    let catalog: TargetCatalog

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        // Drop callbacks arrive on the main thread; the catalog is main-actor bound.
        MainActor.assumeIsolated {
            catalog.move(draggingID, over: targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
