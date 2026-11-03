import Foundation
import Observation

/// The user's picker catalog: every discovered target in a persisted order,
/// with per-target visibility. Settings edits it ("Shown in the picker");
/// the picker consumes `visible` — browsers and Chrome profiles as peers in
/// one flat list.
///
/// Discovery is not stable: Private Window variants come and go with a switch,
/// Chrome profiles vanish while Chrome's folder is unreadable, a browser can be
/// uninstalled and come back. So the saved order and hidden set are the user's
/// intent for *every* target they have ever arranged, and an edit made while
/// some target is missing must not forget that target (see `persist()`).
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
        all = Self.ordered(discovered, by: savedOrder)

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

    /// One-step reorder for VoiceOver / keyboard users, who can't drag:
    /// `offset` -1 moves the target up a slot, +1 down. No-op at the ends.
    func move(_ id: String, by offset: Int) {
        guard let from = all.firstIndex(where: { $0.id == id }),
              all.indices.contains(from + offset) else { return }
        move(id, over: all[from + offset].id)
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

    /// The target a plain click opens in modifier mode, resolved at use time.
    /// The saved choice wins whenever it is discovered; while it isn't (Private
    /// Windows switched off, Chrome unreadable, browser uninstalled) the choice
    /// is kept and this falls back without overwriting it.
    func plainClickTarget() -> LaunchTarget? {
        Self.resolvePlainClick(saved: Preferences.defaultTargetID,
                               priorDefault: DefaultBrowser.capturedPriorDefault,
                               all: all, visible: visible)
    }

    /// Write order + visibility, merged into what's saved so targets that are
    /// not discovered right now keep their slot and hidden state.
    private func persist() {
        let defaults = UserDefaults.standard
        let savedOrder = defaults.stringArray(forKey: Preferences.targetOrderKey) ?? []
        let savedHidden = defaults.stringArray(forKey: Preferences.hiddenTargetsKey) ?? []
        defaults.set(Self.mergedOrder(current: all.map(\.id), saved: savedOrder),
                     forKey: Preferences.targetOrderKey)
        defaults.set(Self.mergedHidden(current: hidden, discovered: Set(all.map(\.id)),
                                       saved: savedHidden),
                     forKey: Preferences.hiddenTargetsKey)
    }

    // MARK: Pure rules (no UserDefaults, no discovery)

    /// Known ids keep their saved order; new discoveries append at the end in
    /// discovery order. Duplicate saved ids count once (first wins).
    nonisolated static func ordered(_ discovered: [LaunchTarget], by savedOrder: [String]) -> [LaunchTarget] {
        let rank = Dictionary(savedOrder.enumerated().map { ($1, $0) },
                              uniquingKeysWith: { first, _ in first })
        return discovered.enumerated().sorted { a, b in
            let ra = rank[a.element.id] ?? savedOrder.count + a.offset
            let rb = rank[b.element.id] ?? savedOrder.count + b.offset
            return ra < rb
        }.map(\.element)
    }

    /// The order to save after an edit. Every saved slot that belongs to a
    /// discovered target is refilled, in turn, from the new order; undiscovered
    /// ids stay in their slot. Discovered ids the saved list never had go last.
    ///
    ///     saved [A, X, B, C] (X missing), new order [C, A, B] → [C, X, A, B]
    nonisolated static func mergedOrder(current: [String], saved: [String]) -> [String] {
        let currentSet = Set(current)
        var seen = Set<String>()
        var next = current.makeIterator()
        var result: [String] = []
        for id in saved where seen.insert(id).inserted {
            if currentSet.contains(id) {
                if let filler = next.next() { result.append(filler) }
            } else {
                result.append(id)
            }
        }
        while let rest = next.next() { result.append(rest) }
        return result
    }

    /// The hidden set to save: the live state for discovered targets, the saved
    /// state for everything else. Sorted so the stored value is deterministic.
    nonisolated static func mergedHidden(current: Set<String>, discovered: Set<String>,
                                         saved: [String]) -> [String] {
        let keptForMissing = saved.filter { !discovered.contains($0) }
        return Array(current.union(keptForMissing)).sorted()
    }

    /// Saved choice if discovered → the browser that was the system default
    /// before BrowBro (what "plain clicks open your default browser" promises)
    /// → the top of the picker → anything at all.
    nonisolated static func resolvePlainClick(saved: String?, priorDefault: String?,
                                              all: [LaunchTarget],
                                              visible: [LaunchTarget]) -> LaunchTarget? {
        if let saved, let target = all.first(where: { $0.id == saved }) { return target }
        if let priorDefault, let target = all.first(where: { $0.id == "app:\(priorDefault)" }) {
            return target
        }
        return visible.first ?? all.first
    }
}
