import SwiftUI
import AppKit

/// First-run onboarding: transparent, reversible default-browser takeover.
/// Captures the current default, becomes the default, and keeps the prior one
/// as a restorable target. Warm but honest — the wink lives in the copy.
struct OnboardingView: View {
    var onClose: () -> Void

    @State private var isDefault = DefaultBrowser.isBrowBro
    @State private var working = false

    /// The browser being replaced (captured prior default, or the live one).
    private var currentDefault: (name: String, appURL: URL)? {
        if let prior = DefaultBrowser.priorDefaultApp() { return prior }
        guard
            let url = DefaultBrowser.currentURL(),
            Bundle(url: url)?.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        return (name, url)
    }

    var body: some View {
        VStack(spacing: 8) {
            AppIconView(size: 72)
                .padding(.bottom, 4)

            Text("Every link, your call")
                .font(BBFont.headline)
                .tracking(-0.24)
                .foregroundStyle(BB.textPrimary)

            Text("Make BrowBro your default browser and it'll quietly step in — the next time you click a link, it asks where to open it. That's the whole trick.")
                .font(BBFont.body)
                .foregroundStyle(BB.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 320)

            if let current = currentDefault {
                HStack(spacing: 8) {
                    AppIconChip(appURL: current.appURL, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Currently: \(current.name)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(BB.textPrimary)
                        Text("We'll keep it as a target — restore it as default anytime.")
                            .font(BBFont.caption)
                            .foregroundStyle(BB.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(BB.surfaceSunken, in: RoundedRectangle(cornerRadius: BB.radiusMD, style: .continuous))
                .padding(.top, 4)
            }

            if isDefault {
                VStack(spacing: 6) {
                    Text("✓ BrowBro is now your default browser")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BB.success)
                    HStack(spacing: 6) {
                        if let current = currentDefault {
                            Button("Restore \(current.name)") {
                                Task {
                                    try? await DefaultBrowser.restorePriorDefault()
                                    isDefault = DefaultBrowser.isBrowBro
                                }
                            }
                            .buttonStyle(BBButtonStyle(variant: .secondary, size: .md, fullWidth: true))
                        }
                        Button("Done") { onClose() }
                            .buttonStyle(BBButtonStyle(variant: .primary, size: .md, fullWidth: true))
                    }
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 6) {
                    Button(working ? "Setting…" : "Set BrowBro as default browser") {
                        Task {
                            working = true
                            defer { working = false }
                            try? await DefaultBrowser.setAsDefault()
                            isDefault = DefaultBrowser.isBrowBro
                        }
                    }
                    .buttonStyle(BBButtonStyle(variant: .primary, size: .lg, fullWidth: true))
                    .disabled(working)

                    Button("Maybe later") { onClose() }
                        .buttonStyle(BBButtonStyle(variant: .ghost, size: .md, fullWidth: true))
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(BB.surfaceRaised)
    }
}

/// Presents onboarding in its own centered window on first run (and from
/// wherever setup needs to be re-run).
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    static let shared = OnboardingController()
    private override init() {}

    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: OnboardingView { [weak self] in
                self?.close()
            })
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = "Welcome to BrowBro"
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.close()   // triggers windowWillClose
    }

    func windowWillClose(_ notification: Notification) {
        Preferences.hasCompletedOnboarding = true
        window = nil
    }
}
