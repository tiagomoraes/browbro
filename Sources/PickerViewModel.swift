import AppKit
import Observation

/// Best-effort "from {app}" attribution for the picker header — whatever app
/// was frontmost when the link arrived.
struct SourceApp {
    let name: String
    let icon: NSImage?
}

/// State + keyboard behavior for the picker. Mutated by the panel's key
/// handler; observed by the SwiftUI view.
///
/// Keyboard model (DESIGN.md / Picker.jsx, with one-keystroke digits):
///   ↑ / ↓   move the highlight (clamped at the ends)
///   1–9     open that target immediately (the badge is its position)
///   A–Z     jump to the first target starting with that letter
///   Enter   open the highlighted target
///   ⌘C     copy the URL
///   Esc     cancel — the link does not open
@MainActor
@Observable
final class PickerViewModel {
    let url: URL
    let source: SourceApp?
    let targets: [LaunchTarget]
    private(set) var selectedIndex: Int
    private(set) var copied = false
    private var copiedGeneration = 0

    var onCommit: ((LaunchTarget) -> Void)?
    var onCancel: (() -> Void)?

    init(url: URL, targets: [LaunchTarget], source: SourceApp? = nil, initialSelection: Int = 0) {
        self.url = url
        self.targets = targets
        self.source = source
        self.selectedIndex = targets.isEmpty ? 0 : min(max(initialSelection, 0), targets.count - 1)
    }

    func select(_ index: Int) {
        guard targets.indices.contains(index) else { return }
        selectedIndex = index
    }

    func moveDown() { select(selectedIndex + 1) }
    func moveUp() { select(selectedIndex - 1) }

    func commitSelected() {
        commit(at: selectedIndex)
    }

    func commit(at index: Int) {
        guard targets.indices.contains(index) else { return }
        onCommit?(targets[index])
    }

    func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        copied = true
        copiedGeneration += 1
        let generation = copiedGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if copiedGeneration == generation { copied = false }
        }
    }

    /// Handle a key event forwarded from the panel. Returns true if consumed.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: onCancel?(); return true            // esc
        case 36, 76: commitSelected(); return true   // return / enter
        case 125: moveDown(); return true            // down arrow
        case 126: moveUp(); return true              // up arrow
        default:
            break
        }
        let chars = event.charactersIgnoringModifiers?.lowercased()
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        // keyCode 8 = "C" on a US keyboard; characters cover other layouts.
        if mods == .command, chars == "c" || event.keyCode == 8 {
            copyURL()
            return true
        }
        guard mods.isEmpty,
              let chars = chars, chars.count == 1
        else { return false }
        if let n = Int(chars), (1...9).contains(n) {   // digit = open that target
            commit(at: n - 1)
            return true
        }
        if chars.first?.isLetter == true {             // first-letter jump
            if let hit = targets.firstIndex(where: { $0.name.lowercased().hasPrefix(chars) }) {
                select(hit)
            }
            return true
        }
        return false
    }
}
