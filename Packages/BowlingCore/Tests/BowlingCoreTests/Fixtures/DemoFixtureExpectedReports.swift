import BowlingCore
import Testing
import BowlingFixtures

// Hand-computed 1a stats (§6 "Definitions (1a)") for three scopes of the fixture, all
// with the all-time date preset. Per-game inputs are in DemoFixtureExpectedGames.swift.
// Readings of open questions in the draft contract that these numbers rely on:
// - OQ-9: incomplete games are excluded everywhere, series included.
// - OQ-16: one trend point per session; its rolling average covers the last nine
//   complete games up to the end of that session, or all of them when fewer exist.
// - OQ-17: the "left most, made least" score is count x miss rate, which is the miss
//   count. Leave rows with equal counts have no pinned order here.
// - OQ-19: "last N" orders games by session date, then gameIndex.
// - Fouls per game divide by rollGames, since a finalOnly game has no rolls.
// - Split % divides by every spare attempt in a pinByPin game, a first-ball foul's
//   attempt included, although that attempt has no leave (§5, §6).

/// numerator / denominator, kept unreduced so the denominator shown in the UI is visible.
struct Ratio: Sendable, Hashable {
    let numerator: Int
    let denominator: Int

    init(_ numerator: Int, of denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }
}

struct ExpectedSeries: Sendable, Hashable {
    let gameCount: Int
    let total: Int
    let session: DemoSession
}

struct ExpectedTrendPoint: Sendable, Hashable {
    let session: DemoSession
    let sessionAverage: Ratio
    let rollingAverage: Ratio
}

struct ExpectedLeaveRow: Sendable, Hashable {
    let count: Int
    let converted: Int
}

struct ExpectedReport: Sendable {
    let bowler: DemoBowler
    let eventTypes: Set<EventType>
    /// Complete games in scope, oldest first (session date, then gameIndex).
    let games: [DemoGame]

    let scoreGames: Int
    let rollGames: Int
    let pinGames: Int

    let average: Ratio
    let averageLast10: Ratio
    let averageLast30: Ratio
    let highGame: (score: Int, game: DemoGame)
    /// Best per game count, ascending game count.
    let highSeries: [ExpectedSeries]
    /// Ascending date.
    let trend: [ExpectedTrendPoint]

    let firstBalls: Int
    let strikes: Ratio
    let spares: Ratio
    let fouls: Ratio

    let splitRate: Ratio
    let splitConversion: Ratio
    let makeableConversion: Ratio
    let singlePinConversion: Ratio
    let leaves: [String: ExpectedLeaveRow]
    /// Rows whose order is pinned: every other row's count is strictly smaller.
    let leavesHead: [String]
    /// Nil when no leave was seen at least 3 times (contract OQ-17).
    let leftMostMadeLeast: String?
}

extension DemoFixtureExpected {
    /// The owner's default scope (§6): they have complete league and tournament games.
    static let ownerCompetition = ExpectedReport(
        bowler: .owner,
        eventTypes: EventType.competition,
        games: [
            .earlyLeague1, .earlyLeague2, .earlyLeague3,                    // 16 days ago
            .tournament1, .tournament2, .tournament3, .tournament4,         // 9 days ago
            .leagueNight1, .leagueNight2, .leagueNight3,                    // 2 days ago
        ],
        scoreGames: 10,
        rollGames: 8,       // 10 minus finalOnly tournament3 and earlyLeague3
        pinGames: 5,        // leagueNight1-3, tournament1, earlyLeague2
        // 150+160+201 = 511; 300+170+188+183 = 841; 162+213+160 = 535
        // 511 + 841 + 535 = 1887
        average: Ratio(1887, of: 10),
        averageLast10: Ratio(1887, of: 10),
        averageLast30: Ratio(1887, of: 10),
        highGame: (300, .tournament1),
        highSeries: [
            ExpectedSeries(gameCount: 3, total: 535, session: .leagueNight),  // 535 > 511
            ExpectedSeries(gameCount: 4, total: 841, session: .tournament),
        ],
        trend: [
            ExpectedTrendPoint(session: .earlyLeague, sessionAverage: Ratio(511, of: 3),
                               rollingAverage: Ratio(511, of: 3)),
            // 511 + 841 = 1352 over 7 games
            ExpectedTrendPoint(session: .tournament, sessionAverage: Ratio(841, of: 4),
                               rollingAverage: Ratio(1352, of: 7)),
            // last nine drop earlyLeague1 (150): 1887 - 150 = 1737
            ExpectedTrendPoint(session: .leagueNight, sessionAverage: Ratio(535, of: 3),
                               rollingAverage: Ratio(1737, of: 9)),
        ],
        // earlyLeague1 11 + earlyLeague2 11 + tournament1 12 + tournament2 10
        // + tournament4 11 + leagueNight1 11 + leagueNight2 12 + leagueNight3 11 = 89
        firstBalls: 89,
        // 0 + 3 + 12 + 4 + 5 + 4 + 7 + 3 = 38
        strikes: Ratio(38, of: 89),
        // spares 10 + 4 + 0 + 3 + 3 + 4 + 2 + 5 = 31
        // attempts 10 + 7 + 0 + 6 + 6 + 7 + 4 + 8 = 48
        spares: Ratio(31, of: 48),
        // earlyLeague2 1 + tournament4 1 + leagueNight1 1 + leagueNight2 1 = 4
        fouls: Ratio(4, of: 8),
        // pinByPin attempts: earlyLeague2 7 + tournament1 0 + leagueNight1 7
        // + leagueNight2 4 + leagueNight3 8 = 26, two of them after a first-ball foul.
        // Splits: 5-7, 7-10, 4-5, 6-7-10, 4-7-10 = 5
        splitRate: Ratio(5, of: 26),
        splitConversion: Ratio(1, of: 5),                // only the 4-5
        // Single pins: earlyLeague2 4 (2 made) + leagueNight1 2 (2) + leagueNight2 2 (0)
        // + leagueNight3 4 (3) = 12 (7 made).
        // Makeable: 2-4-5 (made), 2-8 (made), 3-6-10, 1-2-10, 6-10 (made), 3-9 (made),
        // 1-2-4-10 (made) = 7 (5 made). Together 7+5 = 12 made of 12+7 = 19.
        // Check: 19 + 5 splits + 2 foul attempts = 26.
        makeableConversion: Ratio(12, of: 19),
        singlePinConversion: Ratio(7, of: 12),
        leaves: [
            // earlyLeague2 3 (1 made) + leagueNight1 2 (2) + leagueNight3 1 (1)
            "10": ExpectedLeaveRow(count: 6, converted: 4),
            "7": ExpectedLeaveRow(count: 2, converted: 1),   // leagueNight2 miss, earlyLeague2 made
            "2": ExpectedLeaveRow(count: 1, converted: 0),
            "5": ExpectedLeaveRow(count: 1, converted: 0),
            "8": ExpectedLeaveRow(count: 1, converted: 1),
            "9": ExpectedLeaveRow(count: 1, converted: 1),
            "1-2-10": ExpectedLeaveRow(count: 1, converted: 0),
            "1-2-4-10": ExpectedLeaveRow(count: 1, converted: 1),
            "2-4-5": ExpectedLeaveRow(count: 1, converted: 1),
            "2-8": ExpectedLeaveRow(count: 1, converted: 1),
            "3-6-10": ExpectedLeaveRow(count: 1, converted: 0),
            "3-9": ExpectedLeaveRow(count: 1, converted: 1),
            "4-5": ExpectedLeaveRow(count: 1, converted: 1),
            "4-7-10": ExpectedLeaveRow(count: 1, converted: 0),
            "5-7": ExpectedLeaveRow(count: 1, converted: 0),
            "6-10": ExpectedLeaveRow(count: 1, converted: 1),
            "6-7-10": ExpectedLeaveRow(count: 1, converted: 0),
            "7-10": ExpectedLeaveRow(count: 1, converted: 0),
        ],
        leavesHead: ["10", "7"],
        // Only 10 (count 6) is seen at least 3 times; misses 6 - 4 = 2.
        leftMostMadeLeast: "10"
    )

    /// The owner with every event type. The in-progress practice game stays out.
    static let ownerAllGames = ExpectedReport(
        bowler: .owner,
        eventTypes: Set(EventType.allCases),
        games: [
            .casualOuting1, .casualOuting2,                                 // 40 days ago
            .earlyLeague1, .earlyLeague2, .earlyLeague3,                    // 16 days ago
            .tournament1, .tournament2, .tournament3, .tournament4,         // 9 days ago
            .practice1, .practice2,                                         // 5 days ago
            .leagueNight1, .leagueNight2, .leagueNight3,                    // 2 days ago
        ],
        scoreGames: 14,
        rollGames: 11,      // competition 8 + practice1, practice2, casualOuting2
        pinGames: 6,        // competition 5 + practice1
        // 142+124 = 266 casual; 181+149 = 330 practice; 1887 + 266 + 330 = 2483
        average: Ratio(2483, of: 14),
        // last ten: earlyLeague3 201 + tournament 841 + practice 330 + leagueNight 535 = 1907
        averageLast10: Ratio(1907, of: 10),
        averageLast30: Ratio(2483, of: 14),
        highGame: (300, .tournament1),
        highSeries: [
            ExpectedSeries(gameCount: 2, total: 330, session: .practice),     // 330 > 266
            ExpectedSeries(gameCount: 3, total: 535, session: .leagueNight),
            ExpectedSeries(gameCount: 4, total: 841, session: .tournament),
        ],
        trend: [
            ExpectedTrendPoint(session: .casualOuting, sessionAverage: Ratio(266, of: 2),
                               rollingAverage: Ratio(266, of: 2)),
            // 266 + 511 = 777 over 5
            ExpectedTrendPoint(session: .earlyLeague, sessionAverage: Ratio(511, of: 3),
                               rollingAverage: Ratio(777, of: 5)),
            // 777 + 841 = 1618 over 9
            ExpectedTrendPoint(session: .tournament, sessionAverage: Ratio(841, of: 4),
                               rollingAverage: Ratio(1618, of: 9)),
            // 11 games; last nine drop casualOuting 266: 1618 + 330 - 266 = 1682
            ExpectedTrendPoint(session: .practice, sessionAverage: Ratio(330, of: 2),
                               rollingAverage: Ratio(1682, of: 9)),
            // 14 games; last nine drop casualOuting 266 and earlyLeague 511:
            // 2483 - 777 = 1706
            ExpectedTrendPoint(session: .leagueNight, sessionAverage: Ratio(535, of: 3),
                               rollingAverage: Ratio(1706, of: 9)),
        ],
        firstBalls: 120,                    // 89 + practice1 11 + practice2 10 + casualOuting2 10
        strikes: Ratio(47, of: 120),        // 38 + 4 + 3 + 2
        spares: Ratio(39, of: 69),          // spares 31 + 4 + 2 + 2; attempts 48 + 6 + 7 + 8
        fouls: Ratio(4, of: 11),
        // practice1 adds 6 attempts (26 + 6 = 32) and the 6-7-10 split (5 + 1 = 6)
        splitRate: Ratio(6, of: 32),
        splitConversion: Ratio(1, of: 6),
        // practice1 singles 10 (made), 7 (made), 10, 3 (made), 10 (made): 5, 4 made.
        // Singles 12 + 5 = 17, 7 + 4 = 11 made. Makeable unchanged at 7, 5 made.
        // Together 11 + 5 = 16 of 17 + 7 = 24. Check: 24 + 6 + 2 fouls = 32.
        makeableConversion: Ratio(16, of: 24),
        singlePinConversion: Ratio(11, of: 17),
        leaves: [
            "10": ExpectedLeaveRow(count: 9, converted: 6),          // 6 + 3, 4 + 2
            "7": ExpectedLeaveRow(count: 3, converted: 2),           // 2 + 1, 1 + 1
            "6-7-10": ExpectedLeaveRow(count: 2, converted: 0),      // leagueNight3, practice1
            "2": ExpectedLeaveRow(count: 1, converted: 0),
            "3": ExpectedLeaveRow(count: 1, converted: 1),
            "5": ExpectedLeaveRow(count: 1, converted: 0),
            "8": ExpectedLeaveRow(count: 1, converted: 1),
            "9": ExpectedLeaveRow(count: 1, converted: 1),
            "1-2-10": ExpectedLeaveRow(count: 1, converted: 0),
            "1-2-4-10": ExpectedLeaveRow(count: 1, converted: 1),
            "2-4-5": ExpectedLeaveRow(count: 1, converted: 1),
            "2-8": ExpectedLeaveRow(count: 1, converted: 1),
            "3-6-10": ExpectedLeaveRow(count: 1, converted: 0),
            "3-9": ExpectedLeaveRow(count: 1, converted: 1),
            "4-5": ExpectedLeaveRow(count: 1, converted: 1),
            "4-7-10": ExpectedLeaveRow(count: 1, converted: 0),
            "5-7": ExpectedLeaveRow(count: 1, converted: 0),
            "6-10": ExpectedLeaveRow(count: 1, converted: 1),
            "7-10": ExpectedLeaveRow(count: 1, converted: 0),
        ],
        leavesHead: ["10", "7"],
        // Seen at least 3 times: 10 (9, misses 3) and 7 (3, misses 1).
        leftMostMadeLeast: "10"
    )

    /// The friend has no league or tournament games, so their default scope falls back
    /// to all games (§6, §9).
    static let friendAllGames = ExpectedReport(
        bowler: .friend,
        eventTypes: Set(EventType.allCases),
        games: [
            .friendPractice1, .friendPractice2,     // 20 days ago
            .friendCasual1, .friendCasual2,         // 3 days ago
        ],
        scoreGames: 4,
        rollGames: 3,       // friendCasual2 is finalOnly
        pinGames: 1,        // friendCasual1
        // 157 + 150 = 307 practice; 150 + 131 = 281 casual; 307 + 281 = 588
        average: Ratio(588, of: 4),
        averageLast10: Ratio(588, of: 4),
        averageLast30: Ratio(588, of: 4),
        highGame: (157, .friendPractice1),
        highSeries: [
            ExpectedSeries(gameCount: 2, total: 307, session: .friendPractice),  // 307 > 281
        ],
        trend: [
            ExpectedTrendPoint(session: .friendPractice, sessionAverage: Ratio(307, of: 2),
                               rollingAverage: Ratio(307, of: 2)),
            ExpectedTrendPoint(session: .friendCasual, sessionAverage: Ratio(281, of: 2),
                               rollingAverage: Ratio(588, of: 4)),
        ],
        firstBalls: 32,                     // 11 + 11 + 10
        strikes: Ratio(9, of: 32),          // 3 + 3 + 3
        spares: Ratio(10, of: 22),          // spares 3 + 4 + 3; attempts 7 + 8 + 7
        fouls: Ratio(1, of: 3),             // friendPractice2's second-ball foul
        // friendCasual1: 7 attempts, the 7-10 is the only split and is missed
        splitRate: Ratio(1, of: 7),
        splitConversion: Ratio(0, of: 1),
        // singles 10 (made), 7, 6 (made), 4, 10 (made), 4: 3 of 6, no multi-pin makeable
        makeableConversion: Ratio(3, of: 6),
        singlePinConversion: Ratio(3, of: 6),
        leaves: [
            "10": ExpectedLeaveRow(count: 2, converted: 2),
            "4": ExpectedLeaveRow(count: 2, converted: 0),
            "6": ExpectedLeaveRow(count: 1, converted: 1),
            "7": ExpectedLeaveRow(count: 1, converted: 0),
            "7-10": ExpectedLeaveRow(count: 1, converted: 0),
        ],
        leavesHead: [],     // "10" and "4" tie at 2 (OQ-17)
        // The 4 has the most misses (2 of 2) but the most any leave was seen is 2, below
        // the minimum of 3, so nothing qualifies (OQ-17).
        leftMostMadeLeast: nil
    )

    static let reports = [ownerCompetition, ownerAllGames, friendAllGames]
}

extension ExpectedReport: CustomTestStringConvertible {
    var testDescription: String {
        "\(bowler), \(eventTypes == EventType.competition ? "competition" : "all games")"
    }
}
