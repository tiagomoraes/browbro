import SwiftUI

@main
struct BrowBroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = LinkStore.shared

    var body: some Scene {
        MenuBarExtra("BrowBro", systemImage: "arrow.up.right.square") {
            MenuContentView()
                .environment(store)
        }
        .menuBarExtraStyle(.window)
    }
}
