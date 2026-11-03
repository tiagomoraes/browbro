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
///   Esc     cancel — the link does not open
@MainActor
@Observable
final class PickerViewModel {
    let url: URL
    let source: SourceApp?
    let targets: [LaunchTarget]
    private(set) var selectedIndex: Int

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
        // Digits go by physical key and come before the ⌘ guard: the trigger
        // key (⌘ or ⇧) is often still held when the picker appears, ⇧1 types
        // "!", and AZERTY's unshifted top row types "&é\"'(…", not digits.
        if let n = Self.digit(forKeyCode: event.keyCode) {   // digit = open that target
            commit(at: n - 1)
            return true
        }
        guard !event.modifierFlags.contains(.command),
              let chars = event.charactersIgnoringModifiers?.lowercased(), chars.count == 1
        else { return false }
        if chars.first?.isLetter == true {             // first-letter jump
            if let hit = targets.firstIndex(where: { $0.name.lowercased().hasPrefix(chars) }) {
                select(hit)
            }
            return true
        }
        return false
    }

    /// Quick-key digit 1–9 for a virtual key code, whatever the layout or
    /// modifiers: the number row (kVK_ANSI_1…9) and the keypad (kVK_ANSI_Keypad1…9).
    /// 0 is not a quick key.
    nonisolated static func digit(forKeyCode keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18, 83: 1
        case 19, 84: 2
        case 20, 85: 3
        case 21, 86: 4
        case 23, 87: 5
        case 22, 88: 6
        case 26, 89: 7
        case 28, 91: 8
        case 25, 92: 9
        default: nil
        }
    }
}
