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
        let tally = rolled.map(RollTally.init).reduce(RollTally(), +)
        let pinAttempts = pinned.map(RollTally.init).reduce(RollTally(), +).spareAttempts
        let leaves = leaveRows(pinAttempts)
        func conversion(_ kinds: Set<LeaveKind>) -> Rate {
            let matching = leaves.filter { kinds.contains($0.leave.kind) }.map(\.conversion)
            return Rate(hits: matching.map(\.hits).reduce(0, +), attempts: matching.map(\.attempts).reduce(0, +))
        }
        let splits = conversion([.split])
        return StatsReport(
            filter: filter, scoreGames: scored.count, rollGames: rolled.count, pinGames: pinned.count,
            average: average(scored), averageLast10: average(scored.suffix(10)),
            averageLast30: average(scored.suffix(30)), highGame: highGame(scored),
            highSeries: highSeries(scored), trend: trend(scored),
            firstBalls: tally.firstBalls, strikes: Rate(hits: tally.strikes, attempts: tally.firstBalls),
            spares: Rate(hits: tally.spareAttempts.filter(\.isConverted).count, attempts: tally.spareAttempts.count),
            fouls: Mean(total: tally.fouls, count: rolled.count),
            splitRate: Rate(hits: splits.attempts, attempts: pinAttempts.count), splitConversion: splits,
            makeableConversion: conversion([.makeable, .singlePin]), singlePinConversion: conversion([.singlePin]),
            leaves: leaves, leftMostMadeLeast: leftMostMadeLeast(leaves)
        )
    }

    /// §6 "Default scope": league and tournament when `preferCompetition` (from
    /// `StatsPreset.prefersCompetition` or the Settings choice) and the bowler has at least
    /// one complete league or tournament game; otherwise every event type. `games` may hold
    /// every bowler's games; the repository's `defaultEventTypes(for:preferCompetition:)`
    /// passes them here.
    public static func defaultEventTypes(
        games: [GameRecord], bowler: BowlerID, preferCompetition: Bool
    ) -> Set<EventType> {
        let hasCompetition = games.contains {
            $0.bowlerID == bowler && $0.isComplete && EventType.competition.contains($0.eventType)
        }
        return preferCompetition && hasCompetition ? EventType.competition : Set(EventType.allCases)
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

    /// Most left first; equal counts by pin numbers ascending (contract OQ-17). Attempts
    /// after a first-ball foul have no leave (§5) and are left out.
    private static func leaveRows(_ attempts: [SpareAttempt]) -> [LeaveRow] {
        Dictionary(grouping: attempts.filter { $0.leave != nil }) { $0.leave! }
            .map { leave, attempts in
                LeaveRow(leave: leave, conversion: Rate(hits: attempts.filter(\.isConverted).count,
                                                        attempts: attempts.count))
            }
            .sorted {
                $0.conversion.attempts != $1.conversion.attempts
                    ? $0.conversion.attempts > $1.conversion.attempts
                    : $0.leave.pins.pins.lexicographicallyPrecedes($1.leave.pins.pins)
            }
    }

    /// §6: the highest count times miss rate, which is the miss count. A tie goes to the
    /// leave higher in the table, so the one left more often. Nil when nothing was missed.
    private static func leftMostMadeLeast(_ rows: [LeaveRow]) -> LeaveRow? {
        func misses(_ row: LeaveRow) -> Int { row.conversion.attempts - row.conversion.hits }
        guard let worst = rows.min(by: { misses($0) > misses($1) }), misses(worst) > 0 else { return nil }
        return worst
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

/// A first ball that left pins standing, a foul included, and was followed by a second
/// roll on the same rack (§6 "Spare attempts").
struct SpareAttempt {
    var isConverted: Bool
    /// What the first ball left; nil when its pins are unknown (countOnly) or it was a
    /// foul, which respots all ten (§5).
    var leave: Leave?
}

/// The roll counts of one or more games.
struct RollTally {
    /// Every roll on a fresh rack (§6 "First balls"): roll 1 of each frame, plus frame 10
    /// rolls after a strike or spare.
    var firstBalls = 0
    var strikes = 0
    var fouls = 0
    var spareAttempts: [SpareAttempt] = []

    init() {}

    init(_ game: GameRecord) {
        for frame in Scorer.playedFrames(game) {
            let marks = frame.marks
            for (index, (roll, rack)) in zip(frame.rolls, frame.racks).enumerated() {
                if roll.isFoul { fouls += 1 }
                guard rack.isFresh else { continue }
                firstBalls += 1
                if marks[index] == .strike { strikes += 1 }
                // A frame 10 fill ball that leaves pins has no next roll, so it is a first
                // ball but not a spare attempt.
                guard marks[index] != .strike, index + 1 < frame.rolls.count else { continue }
                let standing = roll.isFoul || !roll.pinsKnown ? nil : frame.racks[index + 1].pins
                spareAttempts.append(SpareAttempt(isConverted: marks[index + 1] == .spare,
                                                  leave: standing.map(LeaveClassifier.classify)))
            }
        }
    }

    static func + (lhs: RollTally, rhs: RollTally) -> RollTally {
        var sum = lhs
        sum.firstBalls += rhs.firstBalls
        sum.strikes += rhs.strikes
        sum.fouls += rhs.fouls
        sum.spareAttempts += rhs.spareAttempts
        return sum
    }
}
