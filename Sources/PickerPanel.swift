import AppKit
import SwiftUI
import os

private let pickerLog = Logger(subsystem: "so.aca.browbro", category: "picker")

/// Borderless panel that can take key focus, so the picker is fully keyboard-driven.
/// Key events are forwarded to the view model; unhandled ones fall through.
final class PickerPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }
}

/// Presents the picker at the cursor and routes the choice to the launcher.
@MainActor
final class PickerController {
    static let shared = PickerController()
    private init() {}

    private var panel: PickerPanel?
    private var resignObserver: (any NSObjectProtocol)?

    func present(for url: URL, source: SourceApp? = nil) {
        dismiss(animated: false)

        let catalog = TargetCatalog.shared
        catalog.refresh()
        let targets = catalog.visible
        guard !targets.isEmpty else {
            pickerLog.info("no targets; skipping picker")
            return
        }

        // If only one target is shown, just open it (Settings: skip picker).
        if targets.count == 1 && Preferences.skipSingle {
            launch(targets[0], url: url)
            return
        }

        pickerLog.info("present \(targets.count, privacy: .public) targets: \(targets.map(\.name).joined(separator: ", "), privacy: .public)")

        // Pre-highlight the last used target when the preference is on.
        var initialSelection = 0
        if Preferences.rememberLast,
           let last = Preferences.lastUsedTargetID,
           let index = targets.firstIndex(where: { $0.id == last }) {
            initialSelection = index
        }

        let model = PickerViewModel(url: url, targets: targets, source: source,
                                    initialSelection: initialSelection)
        model.onCommit = { [weak self] target in
            self?.launch(target, url: url)
            self?.dismiss()
        }
        model.onCancel = { [weak self] in self?.dismiss() }

        let hosting = NSHostingView(rootView: PickerView(model: model))
        var size = hosting.fittingSize
        size.width = 360
        if size.height < 60 { size.height = 120 }   // defensive: layout not ready
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]

        let panel = PickerPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.onKeyDown = { [weak model] event in model?.handleKeyDown(event) ?? false }

        position(panel, size: size)
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Click-away / focus-away dismissal: losing key status (click in another
        // app, the desktop, our own menu bar item, Cmd-Tab, …) cancels the picker.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    private func launch(_ target: LaunchTarget, url: URL) {
        BrowserLauncher.launch(target, url: url)
        Preferences.lastUsedTargetID = target.id
        LinkStore.shared.recordOpen(url, in: target.name)
    }

    func dismiss(animated: Bool = true) {
        guard let panel else { return }
        if let observer = resignObserver {
            NotificationCenter.default.removeObserver(observer)
            resignObserver = nil
        }
        self.panel = nil

        if animated {
            // ~90ms fade, no bounce.
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = BBMotion.quick
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        } else {
            panel.orderOut(nil)
        }
    }

    /// Anchor the panel so its top-left sits near the cursor, clamped on-screen.
    private func position(_ panel: NSPanel, size: NSSize) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            panel.setFrameOrigin(mouse)
            return
        }
        var x = mouse.x
        var y = mouse.y - size.height        // screen coords are bottom-up
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
