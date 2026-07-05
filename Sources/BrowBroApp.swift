import SwiftUI

@main
struct BrowBroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = LinkStore.shared

    var body: some Scene {
        // The status item is the unibrow mark as a monochrome template image,
        // so macOS tints it to match the menu bar.
        //
        // The MenuBarExtra is deliberately the ONLY scene. A `Settings` scene
        // would be the app's sole window scene, and macOS can present it
        // uninvited when a clicked link activates the app; Settings is a
        // manually managed window instead (SettingsWindowController).
        MenuBarExtra {
            MenuDropdownView()
                .environment(store)
        } label: {
            Image(nsImage: BBBrand.menuBarIcon())
        }
        .menuBarExtraStyle(.window)
        .commands {
            // Re-add the standard "Settings…" item (⌘,) that the removed
            // Settings scene used to provide, wired to our manually managed
            // window. Main-menu key equivalents fire whenever BrowBro is the
            // active app, which is the shortcut the dropdown advertises.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
