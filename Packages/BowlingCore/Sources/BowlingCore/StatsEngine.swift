import Foundation

/// Spec §6. Pure and synchronous: callers pass games already filtered.
public enum StatsEngine {
    /// `games` is already filtered; `filter` is only carried on the report for labeling.
    /// Incomplete games are ignored, and each stat group uses only the entry modes the
    /// applicability table allows (§6 "Which games count for what").
    public static func report(games: [GameRecord], filter: StatsFilter) -> StatsReport {
        let scored = chronological(games.filter(\.isComplete))
        let rolled = scored.filter { [.countOnly, .pinByPin].contains($0.entryMode) }
        let pinned = rolled.filter { $0.entryMode == .pinByPin }
        return StatsReport(
            filter: filter, scoreGames: scored.count, rollGames: rolled.count, pinGames: pinned.count,
            average: average(scored), averageLast10: average(scored.suffix(10)),
            averageLast30: average(scored.suffix(30)), highGame: highGame(scored),
            highSeries: highSeries(scored), trend: trend(scored),
            firstBalls: 0, strikes: Rate(hits: 0, attempts: 0), spares: Rate(hits: 0, attempts: 0),
            fouls: Mean(total: 0, count: 0),
            splitRate: Rate(hits: 0, attempts: 0), splitConversion: Rate(hits: 0, attempts: 0),
            makeableConversion: Rate(hits: 0, attempts: 0), singlePinConversion: Rate(hits: 0, attempts: 0),
            leaves: [], leftMostMadeLeast: nil
        )
    }

    /// Oldest first: session date, then session, then `gameIndex`. "Last N" and the
    /// trend's rolling average read from the end (contract OQ-19).
    private static func chronological(_ games: [GameRecord]) -> [GameRecord] {
        games.sorted {
            ($0.sessionDate, $0.sessionID?.uuidString ?? "", $0.gameIndex)
                < ($1.sessionDate, $1.sessionID?.uuidString ?? "", $1.gameIndex)
        }
    }

    private static func average(_ games: some Collection<GameRecord>) -> Mean {
        Mean(total: games.map(\.finalScore).reduce(0, +), count: games.count)
    }

    /// The earliest game wins a tie.
    private static func highGame(_ games: [GameRecord]) -> HighGame? {
        guard let best = games.min(by: { $0.finalScore > $1.finalScore }) else { return nil }
        return HighGame(score: best.finalScore, game: GameRef(gameID: best.id, sessionID: best.sessionID, date: best.sessionDate))
    }

    /// One group per session, in chronological order. A game without a session is its
    /// own group.
    private static func sessions(_ games: [GameRecord]) -> [[GameRecord]] {
        games.reduce(into: []) { groups, game in
            if let last = groups.last?.last, let id = game.sessionID, last.sessionID == id {
                groups[groups.count - 1].append(game)
            } else {
                groups.append([game])
            }
        }
    }

    /// §6: per session and bowler, the sum of final scores, best per game count. The
    /// earliest series wins a tie.
    private static func highSeries(_ games: [GameRecord]) -> [HighSeries] {
        let byBowler = Dictionary(grouping: games) { $0.bowlerID }
        let series = byBowler.values.flatMap(sessions).map { session in
            HighSeries(gameCount: session.count, total: session.map(\.finalScore).reduce(0, +),
                       sessionID: session[0].sessionID, date: session[0].sessionDate)
        }
        return Dictionary(grouping: series, by: \.gameCount).values
            .map { candidates in
                candidates.min { $0.total > $1.total || ($0.total == $1.total && $0.date < $1.date) }!
            }
            .sorted { $0.gameCount < $1.gameCount }
    }

    /// One point per session; the rolling average covers the last nine games up to the end
    /// of that session (contract OQ-16).
    private static func trend(_ games: [GameRecord]) -> [TrendPoint] {
        var played: [GameRecord] = []
        return sessions(games).map { session in
            played += session
            return TrendPoint(sessionID: session[0].sessionID, date: session[0].sessionDate,
                              sessionAverage: average(session), rollingAverage: average(played.suffix(9)))
        }
    }
}
