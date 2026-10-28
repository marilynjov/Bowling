import BowlingCore
import BowlingData
import Foundation

/// The Stats filter and the text its bar shows (spec §1). Kept on `AppModel` while the app
/// runs; not saved.
struct StatsFilterDraft: Hashable {
    enum Scope: Hashable { case competition, allGames, custom }

    var filter: StatsFilter
    var bowlerName: String
    /// Set when the user applies the filter. Until then it follows the owner's default, so
    /// a league owner's first competition game moves Stats to "Competition" as on Home.
    var isExplicit = false

    /// The owner's default for `bowler`: all time, and the default event types with the
    /// owner's scope and bowling style preference, since they are the owner's settings.
    static func defaults(for bowler: BowlerRecord, owner: BowlerRecord, in store: BowlingStore) -> StatsFilterDraft {
        let preferCompetition = StatsPreset.prefersCompetition(scope: owner.statsScope, profile: owner.statsProfile)
        let eventTypes = store.stats.defaultEventTypes(for: bowler.id, preferCompetition: preferCompetition)
        return StatsFilterDraft(filter: StatsFilter(eventTypes: eventTypes, bowlerID: bowler.id), bowlerName: bowler.name)
    }

    /// The applied filter with its bowler's current name, or the owner's default when nil,
    /// never applied, or its bowler is gone. Nil only when there is no owner.
    static func current(_ kept: StatsFilterDraft?, in store: BowlingStore) -> StatsFilterDraft? {
        guard let owner = store.bowlers.owner() else { return nil }
        if var kept, kept.isExplicit, let bowler = store.bowlers.bowlers().first(where: { $0.id == kept.filter.bowlerID }) {
            kept.bowlerName = bowler.name
            return kept
        }
        return defaults(for: owner, owner: owner, in: store)
    }

    var scope: Scope {
        switch filter.eventTypes {
        case EventType.competition: .competition
        case Set(EventType.allCases): .allGames
        default: .custom
        }
    }

    /// Date, scope, bowler.
    var chips: [String] {
        let scopeChip = switch scope {
        case .competition: String(localized: "Competition")
        case .allGames: String(localized: "All games")
        case .custom: EventType.allCases.filter(filter.eventTypes.contains).map(\.title).joined(separator: ", ")
        }
        return [Self.title(filter.datePreset), scopeChip, bowlerName]
    }

    /// A custom scope with no types would match nothing.
    var canApply: Bool { !filter.eventTypes.isEmpty }

    /// Same date; that bowler's default scope.
    func changingBowler(to bowler: BowlerRecord, owner: BowlerRecord, in store: BowlingStore) -> StatsFilterDraft {
        var changed = Self.defaults(for: bowler, owner: owner, in: store)
        changed.filter.datePreset = filter.datePreset
        return changed
    }

    static func title(_ preset: DatePreset) -> String {
        switch preset {
        case .thisWeek: String(localized: "This week")
        case .thisMonth: String(localized: "This month")
        case .last30Days: String(localized: "Last 30 days")
        case .thisSeason: String(localized: "This season")
        case .allTime: String(localized: "All time")
        }
    }
}
