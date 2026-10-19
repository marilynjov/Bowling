import BowlingCore
import Foundation
import SwiftData

/// The games Stats is computed from (spec §6 "Filters", "Default scope").
@MainActor
public final class StatsRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Applies the filter in the store and returns games for `StatsEngine`, of every
    /// completion state, sorted by session date then game index. `thisSeason` is the last
    /// nine months, since 1a has no league filter.
    public func games(matching filter: StatsFilter, now: Date, calendar: Calendar) -> [GameRecord] {
        games(matching: filter, seasonLeague: nil, now: now, calendar: calendar)
    }

    /// - Parameter seasonLeague: The league whose `seasonStart` and `seasonEnd` `thisSeason`
    ///   uses when both are set. It does not restrict games to that league; in 1b it becomes
    ///   the filter's league.
    public func games(matching filter: StatsFilter, seasonLeague: LeagueID?, now: Date, calendar: Calendar) -> [GameRecord] {
        let season = seasonLeague.flatMap(leagueSeason)
        let interval = filter.dateInterval(now: now, calendar: calendar, leagueSeason: season)
        let descriptor = FetchDescriptor<Game>(predicate: Self.predicate(for: filter, in: interval))
        // Sorted after conversion: the key spans Game and Session, and the result is small.
        return ((try? context.fetch(descriptor)) ?? [])
            .map { $0.record() }
            .sorted { ($0.sessionDate, $0.gameIndex) < ($1.sessionDate, $1.gameIndex) }
    }

    /// `EventType.competition` when `preferCompetition` and the bowler has at least one
    /// complete league or tournament game; otherwise every event type, so a bowler with only
    /// casual and practice games still sees stats.
    public func defaultEventTypes(for bowler: BowlerID, preferCompetition: Bool) -> Set<BowlingCore.EventType> {
        let all = Set(BowlingCore.EventType.allCases)
        guard preferCompetition else { return all }
        let competition = BowlingCore.EventType.competition.map(\.rawValue)
        var descriptor = FetchDescriptor<Game>(predicate: #Predicate { game in
            game.isComplete && game.bowler?.id == bowler
                && game.session.flatMap { competition.contains($0.eventType) } == true
        })
        descriptor.fetchLimit = 1
        let hasCompetitionGame = ((try? context.fetchCount(descriptor)) ?? 0) > 0
        return hasCompetitionGame ? BowlingCore.EventType.competition : all
    }

    /// The league's season, when both of its dates are set and in order.
    private func leagueSeason(_ id: LeagueID) -> DateInterval? {
        guard let league = try? context.league(id),
              let start = league.seasonStart, let end = league.seasonEnd, start <= end else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Bowler, date range, and event types, all in the store; 1a needs no in-memory pass.
    /// Games without a session or bowler never match, having no date or owner. Event types
    /// compare stored raw strings: a value this version does not know reads as `.unknown`,
    /// so it matches when `.unknown` is selected, which "All games" always does.
    static func predicate(for filter: StatsFilter, in interval: DateInterval?) -> Predicate<Game> {
        let bowlerID = filter.bowlerID
        let start = interval?.start ?? .distantPast
        let end = interval?.end ?? .distantFuture
        let selected = filter.eventTypes.filter { $0 != .unknown }.map(\.rawValue)
        let known = BowlingCore.EventType.allCases.filter { $0 != .unknown }.map(\.rawValue)
        let includesUnknown = filter.eventTypes.contains(.unknown)
        return #Predicate<Game> { game in
            game.bowler?.id == bowlerID
                && game.session.flatMap { session in
                    session.date >= start && session.date < end
                        && (selected.contains(session.eventType)
                            || (includesUnknown && !known.contains(session.eventType)))
                } == true
        }
    }
}
