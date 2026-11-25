import BowlingCore
import BowlingData
import Foundation

enum LayoutDestination: Hashable, Identifiable {
    case stats, home

    var id: Self { self }
}

/// The working copy of a Stats or Home layout while Customize is open.
struct LayoutDraft: Hashable {
    struct CatalogGroup: Hashable, Identifiable {
        var group: StatsCardGroup
        var cards: [StatsCardID]
        var id: StatsCardGroup { group }
    }

    var destination: LayoutDestination
    private(set) var cards: [StatsCardID]
    /// Whether the owner's stored layout for this destination was non-empty at init.
    let isCustomized: Bool

    init(destination: LayoutDestination, owner: BowlerRecord) {
        self.destination = destination
        switch destination {
        case .stats:
            cards = StatsPreset.displayedStatsCards(layout: owner.statsLayout, profile: owner.statsProfile)
            isCustomized = !owner.statsLayout.isEmpty
        case .home:
            cards = StatsPreset.displayedHomeTiles(layout: owner.homeLayout, profile: owner.statsProfile)
                .filter { Self.offers($0, for: .home) }
            isCustomized = !owner.homeLayout.isEmpty
        }
    }

    /// Cards the destination can show and the draft does not hold, by group in catalog
    /// order; groups with nothing left are left out.
    var catalog: [CatalogGroup] {
        let left = StatsCardID.allCases.filter { Self.offers($0, for: destination) && !cards.contains($0) }
        return StatsCardGroup.allCases.compactMap { group in
            let inGroup = left.filter { $0.group == group }
            return inGroup.isEmpty ? nil : CatalogGroup(group: group, cards: inGroup)
        }
    }

    var canSave: Bool { !cards.isEmpty }

    mutating func add(_ card: StatsCardID) {
        guard Self.offers(card, for: destination), !cards.contains(card) else { return }
        cards.append(card)
    }

    mutating func remove(atOffsets offsets: IndexSet) {
        cards = cards.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().map { cards[$0] }
        let before = source.filter { $0 < destination }.count
        var rest = cards.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        rest.insert(contentsOf: moving, at: destination - before)
        cards = rest
    }

    static func offers(_ card: StatsCardID, for destination: LayoutDestination) -> Bool {
        switch destination {
        case .stats: true
        case .home: StatTileContent.make(card, StatsCardText.emptyReport) != nil
        }
    }
}
