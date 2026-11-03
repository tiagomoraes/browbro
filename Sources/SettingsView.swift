import SwiftUI
import AppKit
import UniformTypeIdentifiers
import os

private let settingsLog = Logger(subsystem: "cloud.tiagomoraes.browbro", category: "settings")

/// BrowBro Settings: default-browser status with restore, Chrome-profile
/// access, the picker catalog (reorder + show/hide), and behavior toggles.
struct SettingsView: View {
    @State private var catalog = TargetCatalog.shared
    #if SPARKLE
    @State private var updater = UpdaterController.shared
    @State private var reminder = UpdateReminder.shared
    #endif
    @State private var isDefault = DefaultBrowser.isBrowBro
    @State private var chromeAccess = false
    /// Why the last "Grant access…" didn't take, shown in the Chrome row.
    @State private var chromeGrantError: String?
    @State private var working = false

    @AppStorage(Preferences.rememberLastKey) private var rememberLast = false
    @AppStorage(Preferences.skipSingleKey) private var skipSingle = false
    @AppStorage(Preferences.requireModifierKey) private var requireModifier = false
    @AppStorage(Preferences.triggerModifierKey) private var triggerModifier: TriggerModifier = .option
    @AppStorage(Preferences.defaultTargetKey) private var defaultTargetID = ""
    @AppStorage(Preferences.privateWindowsEnabledKey) private var privateWindowsEnabled = false
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
                    privateWindowsGroup
                    behaviorGroup
                    #if SPARKLE
                    updatesGroup
                    #endif
                    supportGroup
                    versionFooter
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
        // The window is reused: show() on an open window only brings it
        // forward, and the user may come back from System Settings having
        // changed the default browser or login items. Re-read on every focus.
        .onWindowBecomesKey(perform: refresh)
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
        DefaultBrowser.capturePriorDefault()
        catalog.refresh()
        catalogDidRefresh()
        isDefault = DefaultBrowser.isBrowBro
        chromeAccess = ChromeAccess.canReadLocalState()
        launchAtLogin = LoginItem.isEnabled
        settingsLog.debug("status refreshed: default=\(isDefault, privacy: .public) chrome=\(chromeAccess, privacy: .public) login=\(launchAtLogin, privacy: .public)")
    }

    /// Call after every `catalog.refresh()` in this view. Seeds "open plain
    /// clicks in" on first run with the browser that was the default before
    /// BrowBro when it's in the catalog — that's what a plain click opening
    /// "your default browser" means. A saved choice that is only missing for
    /// now (Private Windows off, Chrome unreadable) is never overwritten: the
    /// picker falls back at use time, and the row below says which browser.
    private func catalogDidRefresh() {
        if defaultTargetID.isEmpty, let seed = catalog.plainClickTarget() {
            defaultTargetID = seed.id
        }
    }

    /// What a plain click opens right now, fallbacks included.
    private var plainClickTarget: LaunchTarget? {
        TargetCatalog.resolvePlainClick(saved: defaultTargetID,
                                        priorDefault: DefaultBrowser.capturedPriorDefault,
                                        all: catalog.all, visible: catalog.visible)
    }

    /// A plain-click choice is saved but not discovered at the moment.
    private var plainClickChoiceMissing: Bool {
        !defaultTargetID.isEmpty && !catalog.all.contains { $0.id == defaultTargetID }
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
                    Image(systemName: chromeGrantError != nil ? "exclamationmark.shield"
                          : chromeAccess ? "checkmark.shield" : "shield")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(chromeGrantError != nil ? BB.warning
                                         : chromeAccess ? BB.success : BB.iconSecondary)
                },
                label: chromeAccess ? "Access granted" : "Grant access to Chrome profiles",
                description: chromeGrantError ?? (chromeAccess
                    ? "BrowBro reads your Chrome profiles to route links per profile."
                    : "BrowBro needs to read Chrome's data folder to list your profiles."),
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
        switch ChromeAccess.requestAccess() {
        case .granted:
            chromeGrantError = nil
        case .cancelled:
            break
        case .wrongFolder(let name):
            chromeGrantError = "“\(name)” isn't Google Chrome's folder. Choose the one named “Chrome” in Application Support › Google."
        case .unreadable:
            chromeGrantError = "That's the right folder, but BrowBro still can't read Chrome's profile list."
        }
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
                            onToggle: { catalog.toggleHidden(target.id) },
                            onMove: { catalog.move(target.id, by: $0) }
                        )
                        .opacity(draggingID == target.id ? 0.4 : 1)
                        .onDrag {
                            draggingID = target.id
                            // A drag that ends anywhere but on a row (outside
                            // the list, Esc, another app) never reaches
                            // performDrop; don't leave the row dimmed.
                            DragEndWatcher.watch { draggingID = nil }
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

    // MARK: Private windows

    /// The Private Windows feature: a master switch, then one opt-in row per
    /// private-capable target. Variants are derived at discovery (ADR-0001),
    /// so every toggle just refreshes the catalog.
    private var privateWindowsGroup: some View {
        SettingsGroup(title: "Private windows") {
            SettingsRow(
                leading: {
                    Image(systemName: "sunglasses.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BB.iconSecondary)
                },
                label: "Open links in private windows",
                description: "Add picker entries that open a browser's incognito or private window.",
                trailing: { BBSwitch(isOn: $privateWindowsEnabled, label: "Open links in private windows") })
            if privateWindowsEnabled {
                ForEach(privateCapableBases) { base in
                    BBDivider().padding(.leading, 12)
                    PrivateOptInRow(
                        base: base,
                        dialect: PrivateWindow.capability(for: base.bundleID)?.dialect ?? "Private",
                        enabled: Preferences.privateEnabledTargets.contains(base.id),
                        onToggle: { togglePrivateVariant(base.id) })
                }
            }
        }
        .animation(BBMotion.easeOut(BBMotion.panel), value: privateWindowsEnabled)
        .onChange(of: privateWindowsEnabled) { _, _ in
            catalog.refresh()
            catalogDidRefresh()
        }
    }

    /// Base (non-variant) targets that can open a Private Window, in catalog order.
    private var privateCapableBases: [LaunchTarget] {
        catalog.all.filter { !$0.isPrivate && PrivateWindow.capability(for: $0.bundleID) != nil }
    }

    private func togglePrivateVariant(_ baseID: String) {
        var enabled = Set(Preferences.privateEnabledTargets)
        if enabled.contains(baseID) {
            enabled.remove(baseID)
        } else {
            enabled.insert(baseID)
        }
        Preferences.privateEnabledTargets = Array(enabled)
        catalog.refresh()
        catalogDidRefresh()
    }

    // MARK: Behavior

    private var behaviorGroup: some View {
        SettingsGroup(title: "Behavior") {
            SettingsRow(
                label: "Ask only when I hold a key",
                description: "Plain clicks open \(plainClickTarget?.name ?? "the browser you choose") right away. Hold \(triggerModifier.symbol) to pop the picker.",
                trailing: { BBSwitch(isOn: $requireModifier, label: "Ask only when I hold a key") })
            if requireModifier {
                BBDivider().padding(.leading, 12)
                SettingsRow(
                    label: "Trigger key",
                    description: "Held while you click a link.",
                    trailing: { ModifierPicker(selection: $triggerModifier) })
                BBDivider().padding(.leading, 12)
                SettingsRow(
                    label: "Open plain clicks in",
                    description: plainClickChoiceMissing
                        ? "Your pick isn't available right now, so plain clicks open \(plainClickTarget?.name ?? "another browser") until it's back."
                        : "The browser a link opens in when you don't hold \(triggerModifier.symbol).",
                    trailing: { defaultTargetPicker })
            }
            BBDivider().padding(.leading, 12)
            SettingsRow(
                label: "Remember last used",
                description: "Pre-highlight whatever you picked last time.",
                trailing: { BBSwitch(isOn: $rememberLast, label: "Remember last used") })
            BBDivider().padding(.leading, 12)
            SettingsRow(
                label: "Skip picker for a single target",
                description: "If only one browser is shown, just open it.",
                trailing: { BBSwitch(isOn: $skipSingle, label: "Skip picker for a single target") })
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
                        }), label: "Launch at login")
                })
        }
        .animation(BBMotion.easeOut(BBMotion.panel), value: requireModifier)
    }

    /// Native popup to choose which browser a plain click opens in (modifier
    /// mode). Lists the whole catalog so a hidden target can still be the default,
    /// plus a placeholder for a saved choice that isn't discovered right now —
    /// the selection must always have a tag, and the choice must survive.
    private var defaultTargetPicker: some View {
        Picker("Open plain clicks in", selection: $defaultTargetID) {
            if plainClickChoiceMissing {
                Text("Unavailable right now").tag(defaultTargetID)
            }
            ForEach(catalog.all) { target in
                Text(target.name).tag(target.id)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(BB.accent)
        .fixedSize()
    }

    // MARK: Updates

    #if SPARKLE
    private var updatesGroup: some View {
        SettingsGroup(title: "Updates") {
            SettingsRow(
                leading: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BB.iconSecondary)
                },
                label: reminder.pendingVersion.map { "BrowBro \($0) is available" } ?? "Check for updates",
                description: "BrowBro installs updates in place — no reinstall, no drag to Applications.",
                trailing: {
                    Button(reminder.pendingVersion == nil ? "Check Now" : "Review…") { updater.checkForUpdates() }
                        .buttonStyle(BBButtonStyle(variant: .secondary, size: .sm))
                        .disabled(!updater.canCheckForUpdates)
                })
            BBDivider().padding(.leading, 12)
            SettingsRow(
                label: "Automatically check for updates",
                description: "Check in the background and let me know when a new version is ready.",
                trailing: {
                    BBSwitch(isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }),
                             label: "Automatically check for updates")
                })
        }
    }
    #endif

    // MARK: Version footer

    /// The at-a-glance "which build am I on" line, kept quiet at the very bottom.
    private var versionFooter: some View {
        Text(Self.versionString)
            .font(BBFont.caption)
            .foregroundStyle(BB.textQuaternary)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    /// "BrowBro 0.1.4 (4)" — short version with the build number in parentheses.
    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        #if APPSTORE
        return "BrowBro \(short) (\(build)) · Mac App Store"
        #else
        return "BrowBro \(short) (\(build))"
        #endif
    }

    // MARK: Support

    /// The ask, kept quiet and last: three link rows, System-Settings style.
    /// The free option is a first-class row on purpose — no tiers, no minimums.
    /// The Mac App Store build omits the payment links (guideline 3.1.1), so its
    /// one row can't be described relative to them.
    private var supportGroup: some View {
        #if APPSTORE
        SettingsGroup(title: "Support the project") {
            SupportLinkRow(
                symbol: "star.fill",
                tile: Color(red: 0xEC / 255, green: 0x9A / 255, blue: 0x00 / 255),
                label: "Star the repo",
                description: "Free — and it helps more people find BrowBro.",
                url: BBLinks.repo)
        }
        #else
        SettingsGroup(title: "Support the project", hint: "any amount helps") {
            SupportLinkRow(
                symbol: "heart.fill",
                tile: Color(red: 0xDB / 255, green: 0x61 / 255, blue: 0xA2 / 255),
                label: "Sponsor on GitHub",
                description: "One-time or monthly — you pick the amount.",
                url: BBLinks.sponsors)
            BBDivider().padding(.leading, 12)
            SupportLinkRow(
                symbol: "cup.and.saucer.fill",
                tile: Color(red: 0xE8 / 255, green: 0x54 / 255, blue: 0x51 / 255),
                label: "Buy me a coffee",
                description: "A one-off on Ko-fi — no account needed.",
                url: BBLinks.kofi)
            BBDivider().padding(.leading, 12)
            SupportLinkRow(
                symbol: "star.fill",
                tile: Color(red: 0xEC / 255, green: 0x9A / 255, blue: 0x00 / 255),
                label: "Star the repo",
                description: "Free — and it helps just as much.",
                url: BBLinks.repo)
        }
        #endif
    }
}

// MARK: - Support link row
// A whole-row external link: colored icon tile (the System Settings idiom),
// hover fill, pointer cursor, and a quiet ↗ so it reads as "leaves the app".

private struct SupportLinkRow: View {
    let symbol: String
    let tile: Color
    let label: String
    let description: String
    let url: URL
    @State private var hovered = false

    var body: some View {
        Button {
            // The user is working inside Settings; the routed URL must not
            // demote the window they just clicked in.
            SettingsWindowController.shared.invalidateOrderSnapshot()
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tile)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BB.textPrimary)
                    Text(description)
                        .font(BBFont.rowSub)
                        .foregroundStyle(BB.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(hovered ? BB.textSecondary : BB.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(hovered ? BB.fillHover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) — opens in your browser")
        .onHover { inside in
            hovered = inside
            (inside ? NSCursor.pointingHand : NSCursor.arrow).set()
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
    /// Reorder by one slot (-1 up, +1 down): dragging has no VoiceOver or
    /// keyboard equivalent, so the row offers these as accessibility actions.
    let onMove: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
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
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(target.name), \(subtitle)")
                .accessibilityValue(hidden ? "Hidden" : "Shown")
                .accessibilityAction(named: "Move up") { onMove(-1) }
                .accessibilityAction(named: "Move down") { onMove(1) }
                Spacer(minLength: 8)
                BBSwitch(isOn: Binding(get: { !hidden }, set: { _ in onToggle() }),
                         label: "Show \(target.name) in the picker")
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
        Group {
            if case .chromeProfile = target.kind {
                ProfileSwatch(name: target.name, colorARGB: target.colorARGB, size: 22)
            } else {
                AppIconChip(appURL: target.appURL, size: 22)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if target.isPrivate {
                PrivateBadge(size: 11)
                    .offset(x: 2.5, y: 2.5)
            }
        }
    }

    private var subtitle: String {
        if target.isPrivate {
            if case .chromeProfile = target.kind {
                return target.subtitle.map { "Private window · \($0)" } ?? "Private window"
            }
            return "Private window"
        }
        if case .chromeProfile = target.kind {
            return target.subtitle.map { "Chrome · \($0)" } ?? "Chrome profile"
        }
        return "Web browser"
    }
}

// MARK: - Private Window opt-in row (switch adds/removes the variant)

private struct PrivateOptInRow: View {
    let base: LaunchTarget
    let dialect: String
    let enabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            leading
            VStack(alignment: .leading, spacing: 1) {
                Text(base.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BB.textPrimary)
                    .lineLimit(1)
                Text("Adds “\(base.name) \(dialect)” to the picker.")
                    .font(BBFont.caption)
                    .foregroundStyle(BB.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            BBSwitch(isOn: Binding(get: { enabled }, set: { _ in onToggle() }),
                     label: "Add \(base.name) \(dialect) to the picker")
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 10))
    }

    @ViewBuilder private var leading: some View {
        if case .chromeProfile = base.kind {
            ProfileSwatch(name: base.name, colorARGB: base.colorARGB, size: 22)
        } else {
            AppIconChip(appURL: base.appURL, size: 22)
        }
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

// MARK: - Modifier segmented control (⌘ ⌥ ⇧)
// The trigger-key chooser for "ask only when I hold a key". Styled from the
// tokens so the on-state reads as BrowBro Blue, not the system accent.
// No ⌃: Control-click is a secondary click, so the link never arrives.

private struct ModifierPicker: View {
    @Binding var selection: TriggerModifier

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TriggerModifier.allCases, id: \.self) { mod in
                let on = mod == selection
                Button {
                    selection = mod
                } label: {
                    Text(mod.symbol)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 22)
                        .foregroundStyle(on ? BB.onAccent : BB.textSecondary)
                        .background(
                            on ? BB.accentFill : BB.fillQuiet,
                            in: RoundedRectangle(cornerRadius: BB.radiusSM, style: .continuous))
                        .overlay {
                            if !on {
                                RoundedRectangle(cornerRadius: BB.radiusSM, style: .continuous)
                                    .strokeBorder(BB.borderHairline, lineWidth: BB.hairline)
                            }
                        }
                }
                .buttonStyle(.plain)
                // The glyph alone reads as a symbol name, and the selected
                // segment is only told apart by color.
                .accessibilityLabel(mod.name)
                .accessibilityAddTraits(on ? .isSelected : [])
                .cursor(.pointingHand)
                .help(mod.name)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trigger key")
        .animation(BBMotion.easeOut(BBMotion.instant), value: selection)
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

/// Ends a catalog drag that never reaches `performDrop` — released outside the
/// list or over another app, or cancelled with Esc. SwiftUI reports none of
/// those, so this watches the hardware instead: once the primary button is up,
/// the drag is over, whatever happened to it.
@MainActor
private enum DragEndWatcher {
    private static var task: Task<Void, Never>?

    static func watch(onEnd: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            while NSEvent.pressedMouseButtons & 1 != 0 {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
            }
            onEnd()
        }
    }
}

/// Live reorder while dragging over rows.
private struct CatalogDropDelegate: DropDelegate {
    let targetID: String
    @Binding var draggingID: String?
    let catalog: TargetCatalog

    /// Only reorders that started in this list: a drag of ours carries one of
    /// the catalog's target ids and has set `draggingID` (cleared when it ends).
    /// Text dragged in from anywhere else has neither.
    func validateDrop(info: DropInfo) -> Bool {
        guard let draggingID, info.hasItemsConforming(to: [.plainText]) else { return false }
        return MainActor.assumeIsolated {
            catalog.all.contains { $0.id == draggingID }
        }
    }

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
