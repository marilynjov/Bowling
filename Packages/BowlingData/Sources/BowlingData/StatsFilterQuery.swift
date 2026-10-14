import Foundation
import SwiftData
import BowlingCore

/// Fetches the games a `StatsFilter` selects (spec section 6 "Filters").
///
/// Stopgap fetch path until the repositories (#21) land; `StatsRepository.games(matching:)`
/// should take this over, including the `GameRecord` conversion below.
enum StatsFilterQuery {
    /// - Parameter seasonLeague: The league whose season dates `thisSeason` uses. In 1b this
    ///   becomes the filter's league; in 1a nothing selects a league, so it is usually nil.
    /// - Returns: Games of every completion state, sorted by session date then game index.
    ///   Games without a session or bowler are left out, since they have no date or owner.
    static func games(
        matching filter: StatsFilter, seasonLeague: LeagueID? = nil,
        now: Date, calendar: Calendar, in context: ModelContext
    ) throws -> [GameRecord] {
        let season = try seasonLeague.flatMap { try leagueSeason($0, in: context) }
        let interval = filter.dateInterval(now: now, calendar: calendar, leagueSeason: season)
        let descriptor = FetchDescriptor<Game>(predicate: predicate(for: filter, in: interval))
        // Sorted after conversion: the key spans Game and Session, and the result is small.
        return try context.fetch(descriptor)
            .compactMap(gameRecord)
            .sorted { ($0.sessionDate, $0.gameIndex) < ($1.sessionDate, $1.gameIndex) }
    }

    /// The season of the league, when both of its dates are set.
    static func leagueSeason(_ id: LeagueID, in context: ModelContext) throws -> DateInterval? {
        var descriptor = FetchDescriptor<League>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let league = try context.fetch(descriptor).first,
              let start = league.seasonStart, let end = league.seasonEnd, start <= end else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Bowler, date range, and event types, all in the store. Event types compare stored raw
    /// strings: a value this version does not know reads as `.unknown`, so it matches when
    /// `.unknown` is selected, which "All games" always does.
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

    private static func gameRecord(_ game: Game) -> GameRecord? {
        guard let session = game.session else { return nil }
        let frames = (game.frames ?? []).sorted { $0.frameIndex < $1.frameIndex }.map { frame in
            FrameRecord(frameIndex: frame.frameIndex, rolls: (frame.rolls ?? [])
                .sorted { $0.rollIndex < $1.rollIndex }
                .map { roll in
                    RollRecord(rollIndex: roll.rollIndex, pinsDown: PinSet(rawValue: UInt16(roll.pinsDownMask)),
                               pinCount: roll.pinCount, pinsKnown: roll.pinsKnown, isFoul: roll.isFoul,
                               ballID: roll.ball?.id)
                })
        }
        return GameRecord(
            id: game.id, bowlerID: game.bowler?.id, gameIndex: game.gameIndex,
            entryMode: BowlingCore.EntryMode(storedValue: game.entryMode), defaultBallID: game.defaultBall?.id,
            finalScore: game.finalScore, isComplete: game.isComplete, frames: frames,
            sessionID: session.id, sessionDate: session.date,
            eventType: BowlingCore.EventType(storedValue: session.eventType))
    }
}
