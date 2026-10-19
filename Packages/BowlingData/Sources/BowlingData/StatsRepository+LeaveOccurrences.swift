import BowlingCore
import Foundation
import SwiftData

extension StatsRepository {
    /// The occurrence list behind a tap on a leave (spec §6 "Leave occurrences"): the games
    /// `games(matching:seasonLeague:now:calendar:)` returns for the same filter, so the list
    /// agrees with the leaves table it was opened from. Newest first, with sessions on the
    /// same date in History's order (`SessionRepository.sessions()`).
    public func leaveOccurrences(of leave: Leave, matching filter: StatsFilter, seasonLeague: LeagueID? = nil,
                                 now: Date, calendar: Calendar) -> [LeaveOccurrence] {
        let games = games(matching: filter, seasonLeague: seasonLeague, now: now, calendar: calendar)
        return StatsEngine.leaveOccurrences(of: leave, games: oldestSessionFirst(games))
    }

    /// The engine orders same-date sessions as they come, a later one being newer, so the
    /// games are passed in reverse History order: History's session sort, reversed.
    private func oldestSessionFirst(_ games: [GameRecord]) -> [GameRecord] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        let newestFirst = ((try? context.fetch(descriptor)) ?? []).map(\.id)
        let rank = Dictionary(newestFirst.enumerated().map { ($1, $0) }, uniquingKeysWith: min)
        // The filter's predicate only returns games with a session.
        func key(_ game: GameRecord) -> (Int, Int) { (game.sessionID.flatMap { rank[$0] } ?? .max, game.gameIndex) }
        return games.sorted { key($0) > key($1) }
    }
}
