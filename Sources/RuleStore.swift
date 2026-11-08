import Foundation
import SwiftUI
import Observation

/// The user's URL rules, persisted as JSON in UserDefaults. Settings edits
/// the list; the picker consults `match(_:)` before presenting.
@MainActor
@Observable
final class RuleStore {
    static let shared = RuleStore()
    private init() { load() }

    /// Enabled rules are tried in this order; the first match wins.
    /// New rules insert at the front so the one you just added takes priority.
    private(set) var rules: [URLRule] = []

    func match(_ url: URL) -> URLRule? {
        rules.first { $0.matches(url) }
    }

    func add(_ rule: URLRule) {
        rules.insert(rule, at: 0)
        persist()
    }

    func setPattern(_ id: UUID, _ pattern: String) {
        guard let i = rules.firstIndex(where: { $0.id == id }) else { return }
        var rule = rules[i]
        rule.pattern = pattern
        rules[i] = rule
        persist()
    }

    func setTarget(_ id: UUID, _ targetID: String) {
        guard let i = rules.firstIndex(where: { $0.id == id }) else { return }
        var rule = rules[i]
        rule.targetID = targetID
        rules[i] = rule
        persist()
    }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        guard let i = rules.firstIndex(where: { $0.id == id }) else { return }
        var rule = rules[i]
        rule.enabled = enabled
        rules[i] = rule
        persist()
    }

    /// Live drag-reorder: move `movedID` to the position of `overID`.
    func move(_ movedID: UUID, over overID: UUID) {
        guard movedID != overID,
              let from = rules.firstIndex(where: { $0.id == movedID }),
              let to = rules.firstIndex(where: { $0.id == overID }) else { return }
        rules.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        persist()
    }

    func remove(id: UUID) {
        rules.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Preferences.rulesKey),
              let decoded = try? JSONDecoder().decode([URLRule].self, from: data)
        else { return }
        rules = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: Preferences.rulesKey)
    }
}
