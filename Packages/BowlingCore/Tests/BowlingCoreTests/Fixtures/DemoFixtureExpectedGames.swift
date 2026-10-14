import BowlingCore
import Testing
import BowlingFixtures

// Hand-computed per-game values for every DemoFixture game, from the definitions in
// spec §4 (scoring) and §6 (stats). Nothing here is computed by a Scorer or StatsEngine:
// each score is worked frame by frame in the comment above it, and the counts follow
// these readings of §6:
// - First balls: roll 1 of frames 1-9, roll 1 of frame 10, and any frame 10 roll on a
//   fresh rack (after a strike or a spare).
// - Spare attempt: a first ball that left pins standing, a foul included, followed by a
//   second roll on the same rack. A frame 10 fill ball that leaves pins is a first ball
//   but not a spare attempt, and its leave is not listed.
// - Leaves: one per spare attempt in a pinByPin game, except after a first-ball foul,
//   which has no leave (§5).

enum ExpectedLeaveKind: Sendable, Hashable {
    case singlePin, makeable, split
}

struct ExpectedLeave: Sendable, Hashable {
    let name: String
    let kind: ExpectedLeaveKind
    let isWashout: Bool
    let converted: Bool

    static func single(_ name: String, made: Bool) -> ExpectedLeave {
        ExpectedLeave(name: name, kind: .singlePin, isWashout: false, converted: made)
    }
    static func makeable(_ name: String, made: Bool, washout: Bool = false) -> ExpectedLeave {
        ExpectedLeave(name: name, kind: .makeable, isWashout: washout, converted: made)
    }
    static func split(_ name: String, made: Bool) -> ExpectedLeave {
        ExpectedLeave(name: name, kind: .split, isWashout: false, converted: made)
    }
}

struct ExpectedGame: Sendable {
    let game: DemoGame
    let finalScore: Int
    /// The rest are nil for finalOnly games, which have no rolls (§6 applicability).
    let firstBalls: Int?
    let strikes: Int?
    let spareAttempts: Int?
    let spares: Int?
    let fouls: Int?
    /// Empty unless pinByPin.
    let leaves: [ExpectedLeave]

    static func finalOnly(_ game: DemoGame, _ finalScore: Int) -> ExpectedGame {
        ExpectedGame(game: game, finalScore: finalScore, firstBalls: nil, strikes: nil,
                     spareAttempts: nil, spares: nil, fouls: nil, leaves: [])
    }
}

enum DemoFixtureExpected {
    static let games: [ExpectedGame] = [
        // F1 10 /: 10+X(10) = 20 | F2 X: 10+8+1 = 19, 39 | F3 7-10 7: 8+1 = 9, 48
        // F4 2-8 /: 10+F(0) = 10, 58 | F5 F /: 10+X(10) = 20, 78 | F6 X: 10+10+7 = 27, 105
        // F7 X: 10+7+2 = 19, 124 | F8 3-6-10 10: 7+2 = 9, 133 | F9 1-2-10 10: 7+2 = 9, 142
        // F10 X 10 /: 10+9+1 = 20, 162
        // First balls 9 + F10 r1 + r2 = 11. Strikes F2 F6 F7 F10r1 = 4.
        // Attempts F1 F3 F4 F5 F8 F9 F10r2 = 7; spares F1 F4 F5 F10 = 4. Foul F5r1.
        ExpectedGame(
            game: .leagueNight1, finalScore: 162, firstBalls: 11, strikes: 4,
            spareAttempts: 7, spares: 4, fouls: 1,
            leaves: [
                .single("10", made: true),
                .split("7-10", made: false),
                .makeable("2-8", made: true),        // sleeper pair, so not a split
                .makeable("3-6-10", made: false),
                .makeable("1-2-10", made: false, washout: true),
                .single("10", made: true),
            ]
        ),
        // F1 X: 10+10+8 = 28 | F2 X: 10+8+2 = 20, 48 | F3 4-5 /: 10+9 = 19, 67
        // F4 7 -: 9+0 = 9, 76 | F5 6-10 /: 10+10 = 20, 96 | F6 X: 10+9+0 = 19, 115
        // F7 5 F: 9+0 = 9, 124 | F8 X: 10+10+10 = 30, 154 | F9 X: 10+10+10 = 30, 184
        // F10 X X 10: 10+10+9 = 29, 213
        // First balls 9 + F10 r1 r2 r3 = 12. Strikes F1 F2 F6 F8 F9 F10r1 F10r2 = 7.
        // Attempts F3 F4 F5 F7 = 4; spares F3 F5 = 2. Foul F7r2.
        ExpectedGame(
            game: .leagueNight2, finalScore: 213, firstBalls: 12, strikes: 7,
            spareAttempts: 4, spares: 2, fouls: 1,
            leaves: [
                .split("4-5", made: true),           // pin 2 down in front of 4 and 5
                .single("7", made: false),
                .makeable("6-10", made: true),
                .single("5", made: false),
            ]
        ),
        // F1 3-9 /: 10+7 = 17 | F2 6-7-10 7: 7+2 = 9, 26 | F3 9 /: 10+10 = 20, 46
        // F4 X: 10+6+4 = 20, 66 | F5 1-2-4-10 /: 10+9 = 19, 85 | F6 2 -: 9, 94
        // F7 X: 10+9+1 = 20, 114 | F8 8 /: 10+7 = 17, 131 | F9 4-7-10 10: 7+2 = 9, 140
        // F10 10 / X: 9+1+10 = 20, 160
        // First balls 9 + F10 r1 + r3 = 11. Strikes F4 F7 F10r3 = 3.
        // Attempts F1 F2 F3 F5 F6 F8 F9 F10r1 = 8; spares F1 F3 F5 F8 F10 = 5.
        ExpectedGame(
            game: .leagueNight3, finalScore: 160, firstBalls: 11, strikes: 3,
            spareAttempts: 8, spares: 5, fouls: 0,
            leaves: [
                .makeable("3-9", made: true),        // sleeper pair
                .split("6-7-10", made: false),
                .single("9", made: true),
                .makeable("1-2-4-10", made: true, washout: true),
                .single("2", made: false),
                .single("8", made: true),
                .split("4-7-10", made: false),
                .single("10", made: true),
            ]
        ),
        // 9/ X 72 X X 81 9/ 63 X 81
        // F1: 10+10 = 20 | F2: 10+7+2 = 19, 39 | F3: 9, 48 | F4: 10+10+8 = 28, 76
        // F5: 10+8+1 = 19, 95 | F6: 9, 104 | F7: 10+6 = 16, 120 | F8: 9, 129
        // F9: 10+8+1 = 19, 148 | F10: 9, 157
        // First balls 10. Strikes F2 F4 F5 F9 = 4. Attempts F1 F3 F6 F7 F8 F10 = 6;
        // spares F1 F7 = 2.
        ExpectedGame(game: .leagueNightPartner1, finalScore: 157, firstBalls: 10, strikes: 4,
                     spareAttempts: 6, spares: 2, fouls: 0, leaves: []),
        // 81 8/ X 9- 7/ X X 9/ 81 X8/
        // F1: 9 | F2: 10+10 = 20, 29 | F3: 10+9+0 = 19, 48 | F4: 9, 57
        // F5: 10+10 = 20, 77 | F6: 10+10+9 = 29, 106 | F7: 10+9+1 = 20, 126
        // F8: 10+8 = 18, 144 | F9: 9, 153 | F10: 10+8+2 = 20, 173
        // First balls 9 + F10 r1 + r2 = 11. Strikes F3 F6 F7 F10r1 = 4.
        // Attempts F1 F2 F4 F5 F8 F9 F10r2 = 7; spares F2 F5 F8 F10 = 4.
        ExpectedGame(game: .leagueNightPartner2, finalScore: 173, firstBalls: 11, strikes: 4,
                     spareAttempts: 7, spares: 4, fouls: 0, leaves: []),
        // -9 X X X 9/ 8- 7/ X 9- 9/7
        // F1: 0+9 = 9 | F2: 10+10+10 = 30, 39 | F3: 10+10+9 = 29, 68
        // F4: 10+9+1 = 20, 88 | F5: 10+8 = 18, 106 | F6: 8, 114 | F7: 10+10 = 20, 134
        // F8: 10+9+0 = 19, 153 | F9: 9, 162 | F10: 9+1+7 = 17, 179
        // First balls 9 + F10 r1 + r3 = 11. Strikes F2 F3 F4 F8 = 4.
        // Attempts F1 F5 F6 F7 F9 F10r1 = 6 (F1's gutter left all ten); spares F5 F7 F10 = 3.
        ExpectedGame(game: .leagueNightPartner3, finalScore: 179, firstBalls: 11, strikes: 4,
                     spareAttempts: 6, spares: 3, fouls: 0, leaves: []),
        // Twelve strikes: 10 x (10+10+10) = 300. First balls 9 + 3 = 12, all strikes.
        ExpectedGame(game: .tournament1, finalScore: 300, firstBalls: 12, strikes: 12,
                     spareAttempts: 0, spares: 0, fouls: 0, leaves: []),
        // X 9/ 81 X X 72 9/ X 8/ 9-
        // F1: 10+9+1 = 20 | F2: 10+8 = 18, 38 | F3: 9, 47 | F4: 10+10+7 = 27, 74
        // F5: 10+7+2 = 19, 93 | F6: 9, 102 | F7: 10+10 = 20, 122 | F8: 10+8+2 = 20, 142
        // F9: 10+9 = 19, 161 | F10: 9, 170
        // First balls 10. Strikes F1 F4 F5 F8 = 4. Attempts F2 F3 F6 F7 F9 F10 = 6;
        // spares F2 F7 F9 = 3.
        ExpectedGame(game: .tournament2, finalScore: 170, firstBalls: 10, strikes: 4,
                     spareAttempts: 6, spares: 3, fouls: 0, leaves: []),
        .finalOnly(.tournament3, 188),
        // 8/ X 9- 7/ X X 81 9/ X XF9
        // F1: 10+10 = 20 | F2: 10+9+0 = 19, 39 | F3: 9, 48 | F4: 10+10 = 20, 68
        // F5: 10+10+8 = 28, 96 | F6: 10+8+1 = 19, 115 | F7: 9, 124 | F8: 10+10 = 20, 144
        // F9: 10+10+F(0) = 20, 164 | F10: 10+0+9 = 19, 183
        // First balls 9 + F10 r1 + r2 (the foul, on a fresh rack) = 11.
        // Strikes F2 F5 F6 F9 F10r1 = 5. Attempts F1 F3 F4 F7 F8 F10r2 = 6 (the foul
        // leaves all ten, r3 is on the same rack); spares F1 F4 F8 = 3. Foul F10r2.
        ExpectedGame(game: .tournament4, finalScore: 183, firstBalls: 11, strikes: 5,
                     spareAttempts: 6, spares: 3, fouls: 1, leaves: []),
        // 5/ in every frame and a 5 fill ball: 9 x (10+5) + (5+5+5) = 135 + 15 = 150.
        // First balls 10 + F10 r3 = 11. Attempts 10, spares 10.
        ExpectedGame(game: .earlyLeague1, finalScore: 150, firstBalls: 11, strikes: 0,
                     spareAttempts: 10, spares: 10, fouls: 0, leaves: []),
        // F1 X: 10+9+0 = 19 | F2 10 -: 9, 28 | F3 10 /: 10+8 = 18, 46
        // F4 5-7 7: 8+1 = 9, 55 | F5 X: 10+7+3 = 20, 75 | F6 2-4-5 /: 10+9 = 19, 94
        // F7 7 /: 10+10 = 20, 114 | F8 X: 10+9+0 = 19, 133 | F9 10 -: 9, 142
        // F10 F / 2-8: 0+10+8 = 18, 160
        // First balls 9 + F10 r1 + r3 = 11. Strikes F1 F5 F8 = 3.
        // Attempts F2 F3 F4 F6 F7 F9 F10r1 = 7; spares F3 F6 F7 F10 = 4. Foul F10r1.
        ExpectedGame(
            game: .earlyLeague2, finalScore: 160, firstBalls: 11, strikes: 3,
            spareAttempts: 7, spares: 4, fouls: 1,
            leaves: [
                .single("10", made: false),
                .single("10", made: true),
                .split("5-7", made: false),
                .makeable("2-4-5", made: true),
                .single("7", made: true),
                .single("10", made: false),
                // F10r1 is a foul: a spare attempt with no leave.
            ]
        ),
        .finalOnly(.earlyLeague3, 201),
        // F1 X: 10+9+1 = 20 | F2 10 /: 10+10 = 20, 40 | F3 X: 10+9+1 = 20, 60
        // F4 7 /: 10+9 = 19, 79 | F5 10 -: 9, 88 | F6 X: 10+10+7 = 27, 115
        // F7 X: 10+7+2 = 19, 134 | F8 6-7-10 7: 7+2 = 9, 143 | F9 3 /: 10+9 = 19, 162
        // F10 10 / 7: 9+1+9 = 19, 181
        // First balls 9 + F10 r1 + r3 = 11. Strikes F1 F3 F6 F7 = 4.
        // Attempts F2 F4 F5 F8 F9 F10r1 = 6; spares F2 F4 F9 F10 = 4.
        ExpectedGame(
            game: .practice1, finalScore: 181, firstBalls: 11, strikes: 4,
            spareAttempts: 6, spares: 4, fouls: 0,
            leaves: [
                .single("10", made: true),
                .single("7", made: true),
                .single("10", made: false),
                .split("6-7-10", made: false),
                .single("3", made: true),
                .single("10", made: true),
            ]
        ),
        // 72 63 X 8/ 9- 81 X X 7/ 81
        // F1: 9 | F2: 9, 18 | F3: 10+8+2 = 20, 38 | F4: 10+9 = 19, 57 | F5: 9, 66
        // F6: 9, 75 | F7: 10+10+7 = 27, 102 | F8: 10+7+3 = 20, 122 | F9: 10+8 = 18, 140
        // F10: 9, 149
        // First balls 10. Strikes F3 F7 F8 = 3. Attempts F1 F2 F4 F5 F6 F9 F10 = 7;
        // spares F4 F9 = 2.
        ExpectedGame(game: .practice2, finalScore: 149, firstBalls: 10, strikes: 3,
                     spareAttempts: 7, spares: 2, fouls: 0, leaves: []),
        .finalOnly(.casualOuting1, 142),
        // 9- 81 X 71 9/ 62 X 9/ 81 72
        // F1: 9 | F2: 9, 18 | F3: 10+7+1 = 18, 36 | F4: 8, 44 | F5: 10+6 = 16, 60
        // F6: 8, 68 | F7: 10+9+1 = 20, 88 | F8: 10+8 = 18, 106 | F9: 9, 115 | F10: 9, 124
        // First balls 10. Strikes F3 F7 = 2. Attempts F1 F2 F4 F5 F6 F8 F9 F10 = 8;
        // spares F5 F8 = 2.
        ExpectedGame(game: .casualOuting2, finalScore: 124, firstBalls: 10, strikes: 2,
                     spareAttempts: 8, spares: 2, fouls: 0, leaves: []),
        // Paused in frame 5 after one ball (OQ-9: finalScore holds the last known running
        // total). F1 X: 10+9+1 = 20 | F2 10 /: 10+8 = 18, 38 | F3 7-10 7: 8+1 = 9, 47
        // F4 X: pending, only one bonus roll exists. Excluded from every stat.
        // First balls F1-F5 = 5. Strikes F1 F4 = 2. Attempts F2 F3 = 2; spares F2 = 1.
        ExpectedGame(
            game: .practiceInProgress, finalScore: 47, firstBalls: 5, strikes: 2,
            spareAttempts: 2, spares: 1, fouls: 0,
            leaves: [
                .single("10", made: true),
                .split("7-10", made: false),
            ]
        ),
        // F1 10 /: 10+9 = 19 | F2 7 -: 9, 28 | F3 X: 10+9+1 = 20, 48 | F4 6 /: 10+9 = 19, 67
        // F5 4 -: 9, 76 | F6 X: 10+9+1 = 20, 96 | F7 10 /: 10+8 = 18, 114
        // F8 7-10 -: 8+0 = 8, 122 | F9 X: 10+9+0 = 19, 141 | F10 4 -: 9, 150
        // First balls 10. Strikes F3 F6 F9 = 3. Attempts F1 F2 F4 F5 F7 F8 F10 = 7;
        // spares F1 F4 F7 = 3.
        ExpectedGame(
            game: .friendCasual1, finalScore: 150, firstBalls: 10, strikes: 3,
            spareAttempts: 7, spares: 3, fouls: 0,
            leaves: [
                .single("10", made: true),
                .single("7", made: false),
                .single("6", made: true),
                .single("4", made: false),
                .single("10", made: true),
                .split("7-10", made: false),
                .single("4", made: false),
            ]
        ),
        .finalOnly(.friendCasual2, 131),
        // 81 X 9/ 72 8/ 9- X X 81 9/8
        // F1: 9 | F2: 10+9+1 = 20, 29 | F3: 10+7 = 17, 46 | F4: 9, 55 | F5: 10+9 = 19, 74
        // F6: 9, 83 | F7: 10+10+8 = 28, 111 | F8: 10+8+1 = 19, 130 | F9: 9, 139
        // F10: 9+1+8 = 18, 157
        // First balls 9 + F10 r1 + r3 = 11. Strikes F2 F7 F8 = 3.
        // Attempts F1 F3 F4 F5 F6 F9 F10r1 = 7; spares F3 F5 F10 = 3.
        ExpectedGame(game: .friendPractice1, finalScore: 157, firstBalls: 11, strikes: 3,
                     spareAttempts: 7, spares: 3, fouls: 0, leaves: []),
        // 7F X 8/ 9- X 9/ 81 7/ 9- 8/X
        // F1: 7+F(0) = 7 | F2: 10+8+2 = 20, 27 | F3: 10+9 = 19, 46 | F4: 9, 55
        // F5: 10+9+1 = 20, 75 | F6: 10+8 = 18, 93 | F7: 9, 102 | F8: 10+9 = 19, 121
        // F9: 9, 130 | F10: 8+2+10 = 20, 150
        // First balls 9 + F10 r1 + r3 = 11. Strikes F2 F5 F10r3 = 3.
        // Attempts F1 F3 F4 F6 F7 F8 F9 F10r1 = 8; spares F3 F6 F8 F10 = 4. Foul F1r2.
        ExpectedGame(game: .friendPractice2, finalScore: 150, firstBalls: 11, strikes: 3,
                     spareAttempts: 8, spares: 4, fouls: 1, leaves: []),
    ]

    static func game(_ game: DemoGame) -> ExpectedGame {
        games.first { $0.game == game }!
    }
}

extension ExpectedGame: CustomTestStringConvertible {
    var testDescription: String { "\(game)" }
}
