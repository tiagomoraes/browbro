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

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor,
                                 withReplyEvent reply: NSAppleEventDescriptor) {
        guard
            let string = event.paramDescriptor(forKeyword: kGetURLDirectObject)?.stringValue,
            let url = URL(string: string)
        else { return }
        LinkStore.shared.receive(url)
    }

    // Belt-and-suspenders: the modern URL-delivery path.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { LinkStore.shared.receive(url) }
    }
}
