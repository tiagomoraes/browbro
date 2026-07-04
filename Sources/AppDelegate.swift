import AppKit

// Four-char codes for the "GetURL" Apple Event. Defined inline so we don't have
// to import the deprecated Carbon framework just for three constants.
//   'GURL' == 0x4755524C, '----' == 0x2D2D2D2D
private let kGetURLEventClass = AEEventClass(0x4755_524C)
private let kGetURLEventID = AEEventID(0x4755_524C)
private let kGetURLDirectObject = AEKeyword(0x2D2D_2D2D)

/// Bridges classic Apple Events (how browsers actually receive clicked links)
/// and the modern `application(_:open:)` path into the LinkStore.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register early so a link that *launched* us is still delivered.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: kGetURLEventClass,
            andEventID: kGetURLEventID
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Guided first run: transparent, reversible default-browser takeover.
        if !Preferences.hasCompletedOnboarding {
            OnboardingController.shared.show()
        }
        // Dev affordance: open a surface at launch for quick visual checks,
        // e.g. `BROWBRO_SHOW=settings ./BrowBro`.
        switch ProcessInfo.processInfo.environment["BROWBRO_SHOW"] {
        case "settings": SettingsWindowController.shared.show()
        case "onboarding": OnboardingController.shared.show()
        default: break
        }
    }

    // A clicked link activates us via LaunchServices, which can arrive with a
    // reopen event. Never let AppKit/SwiftUI respond by conjuring a window —
    // the picker is the only thing a link should summon.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        false
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor,
                                 withReplyEvent reply: NSAppleEventDescriptor) {
        guard
            let string = event.paramDescriptor(forKeyword: kGetURLDirectObject)?.stringValue,
            let url = URL(string: string)
        else { return }
        handle(url)
    }

    // Belt-and-suspenders: the modern URL-delivery path.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handle(url) }
    }

    private func handle(_ url: URL) {
        LinkStore.shared.receive(url)
        // Best-effort source attribution: we're a background accessory, so the
        // frontmost app when the link arrives is almost always its sender.
        PickerController.shared.present(for: url, source: currentSourceApp())
    }

    private func currentSourceApp() -> SourceApp? {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.bundleIdentifier != Bundle.main.bundleIdentifier,
            let name = app.localizedName
        else { return nil }
        return SourceApp(name: name, icon: app.icon)
    }
}
