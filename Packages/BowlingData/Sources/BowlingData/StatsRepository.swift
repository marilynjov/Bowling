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
    /// completion state, sorted by session date then game index. `thisSeason` uses the
    /// filter league's `seasonStart` and `seasonEnd` when both are set, else nine months.
    public func games(matching filter: StatsFilter, now: Date, calendar: Calendar) -> [GameRecord] {
        let season = filter.leagueID.flatMap(leagueSeason)
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
            game.isComplete && game.bowlerID == bowler
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

    /// Every field in the store, so no in-memory pass is needed. Games without a session
    /// or `bowlerID` never match, having no date or owner. A game matches on `bowlerID`
    /// even while its Bowler row is missing (§3.4 "Games with no bowler"). Event types compare stored raw
    /// strings: a value this version does not know reads as `.unknown`, so it matches when
    /// `.unknown` is selected, which "All games" always does.
    static func predicate(for filter: StatsFilter, in interval: DateInterval?) -> Predicate<Game> {
        let bowlerID = filter.bowlerID
        let start = interval?.start ?? .distantPast
        let end = interval?.end ?? .distantFuture
        let selected = filter.eventTypes.filter { $0 != .unknown }.map(\.rawValue)
        let known = BowlingCore.EventType.allCases.filter { $0 != .unknown }.map(\.rawValue)
        let includesUnknown = filter.eventTypes.contains(.unknown)
        // #Predicate cannot test a captured optional for nil, so "any" travels as a Bool.
        let anyCenter = filter.centerID == nil, centerID = filter.centerID ?? UUID()
        let anyLeague = filter.leagueID == nil, leagueID = filter.leagueID ?? UUID()
        let anyPattern = filter.oilPatternID == nil, patternID = filter.oilPatternID ?? UUID()
        let session = #Predicate<Game> { game in
            game.bowlerID == bowlerID
                && game.session.flatMap { session in
                    session.date >= start && session.date < end
                        && (selected.contains(session.eventType)
                            || (includesUnknown && !known.contains(session.eventType)))
                } == true
        }
        // Split from `session` only so the compiler can type-check each in time.
        let places = #Predicate<Game> { game in
            game.session.flatMap { session in
                (anyCenter || session.center?.id == centerID)
                    && (anyLeague || session.league?.id == leagueID)
                    && (anyPattern || session.oilPattern?.id == patternID)
            } == true
        }
        let anyBall = filter.ballID == nil, ballID = filter.ballID ?? UUID()
        let ball = #Predicate<Game> { game in
            anyBall || game.defaultBall?.id == ballID
                || game.frames.flatMap { frames in
                    frames.contains { frame in
                        frame.rolls.flatMap { rolls in rolls.contains { $0.ball?.id == ballID } } == true
                    }
                } == true
        }
        return #Predicate<Game> { session.evaluate($0) && places.evaluate($0) && ball.evaluate($0) }
    }
}
