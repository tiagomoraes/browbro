import Foundation
import Observation

/// The user's picker catalog: every discovered target in a persisted order,
/// with per-target visibility. Settings edits it ("Shown in the picker");
/// the picker consumes `visible` — browsers and Chrome profiles as peers in
/// one flat list.
@MainActor
@Observable
final class TargetCatalog {
    static let shared = TargetCatalog()
    private init() {}

    /// All discovered targets in the user's order, including hidden ones.
    private(set) var all: [LaunchTarget] = []
    private(set) var hidden: Set<String> = []

    var visible: [LaunchTarget] {
        all.filter { !hidden.contains($0.id) }
    }

    /// Re-discover targets and apply the saved order + visibility.
    func refresh() {
        let discovered = TargetDiscovery.all()
        let savedOrder = UserDefaults.standard.stringArray(forKey: Preferences.targetOrderKey) ?? []
        let rank = Dictionary(uniqueKeysWithValues: savedOrder.enumerated().map { ($1, $0) })

        // Known ids keep their saved order; new discoveries append at the end
        // in discovery order.
        all = discovered.enumerated().sorted { a, b in
            let ra = rank[a.element.id] ?? savedOrder.count + a.offset
            let rb = rank[b.element.id] ?? savedOrder.count + b.offset
            return ra < rb
        }.map(\.element)

        let hiddenSaved = UserDefaults.standard.stringArray(forKey: Preferences.hiddenTargetsKey) ?? []
        hidden = Set(hiddenSaved).intersection(Set(discovered.map(\.id)))
    }

    /// Live drag-reorder: move `movedID` to the position of `overID`.
    func move(_ movedID: String, over overID: String) {
        guard movedID != overID,
              let from = all.firstIndex(where: { $0.id == movedID }),
              let to = all.firstIndex(where: { $0.id == overID }) else { return }
        all.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        persist()
    }

    func toggleHidden(_ id: String) {
        if hidden.contains(id) {
            hidden.remove(id)
        } else if visible.count > 1 {
            // Never hide the last visible target — the picker needs somewhere to go.
            hidden.insert(id)
        }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(all.map(\.id), forKey: Preferences.targetOrderKey)
        UserDefaults.standard.set(Array(hidden), forKey: Preferences.hiddenTargetsKey)
    }
}
