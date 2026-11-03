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
            MenuBarGlyph()
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

/// The status item's glyph. In the Sparkle build it wears a dot while a
/// scheduled update waits for the user (gentle reminders, see `Updater.swift`).
private struct MenuBarGlyph: View {
    #if SPARKLE
    @State private var reminder = UpdateReminder.shared
    #endif

    var body: some View {
        #if SPARKLE
        Image(nsImage: BBBrand.menuBarIcon(badged: reminder.pendingVersion != nil))
            .accessibilityLabel(reminder.pendingVersion != nil ? "BrowBro, update available" : "BrowBro")
        #else
        Image(nsImage: BBBrand.menuBarIcon())
            .accessibilityLabel("BrowBro")
        #endif
    }
}
