import BowlingCore
import Foundation

extension StatsRepository {
    /// The occurrence list behind a tap on a leave (spec §6 "Leave occurrences"): the games
    /// `games(matching:seasonLeague:now:calendar:)` returns for the same filter, so the list
    /// agrees with the leaves table it was opened from. Newest first.
    public func leaveOccurrences(of leave: Leave, matching filter: StatsFilter, seasonLeague: LeagueID? = nil,
                                 now: Date, calendar: Calendar) -> [LeaveOccurrence] {
        let games = games(matching: filter, seasonLeague: seasonLeague, now: now, calendar: calendar)
        return StatsEngine.leaveOccurrences(of: leave, games: games)
    }
}
