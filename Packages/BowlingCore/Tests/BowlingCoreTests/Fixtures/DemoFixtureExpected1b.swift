import BowlingCore
import Testing
import BowlingFixtures

// Hand-computed 1b stats (§6 "Definitions (1b)") for the three fixture scopes of
// DemoFixtureExpectedReports.swift. Each game's frames are read off its scoresheet in
// DemoGames.swift; nothing here comes from a Scorer or StatsEngine run. Readings of §6:
// - Open frame: a frame with neither a strike nor a spare mark. In frame 10 a fill ball
//   needs a mark first, so "X 10 -" and "10 / 7" are not open, "4 -" is.
// - Clean game: zero open frames, over rollGames.
// - First-ball average: pins on every first ball (1a definition), a foul counting 0.
// - Head pin rate: pinByPin only (§6 applicability); fouls leave both the numerator and
//   the denominator.
// - By frame: strike on roll 1 over games, and the pins of the frame's first rack, a foul
//   counting 0: the first ball, plus the second unless the first was a strike. Frame 10
//   counts the same way, so its fill balls are left out and the frames stay comparable
//   (review of #82); they still count for the score and every other stat.
// - What-if: every missed single-pin leave becomes a spare (the second ball knocks the
//   pin down); a frame 10 spare made this way gets a fill ball of 0, so the gain is only
//   what the spares themselves earn. A fill-ball leave is not a spare attempt (1a) and is
//   not rewritten.

struct ExpectedGame1b: Sendable {
    let game: DemoGame
    let openFrames: Int
    /// Pins on first balls; the count of first balls is ExpectedGame.firstBalls.
    let firstBallPins: Int
    /// Frames 1...10 whose roll 1 was a strike.
    let strikeFrames: Set<Int>
    /// Pins on each frame's first rack, frames 1...10; frame 10's fill balls left out.
    let framePins: [Int]
    /// pinByPin only: first balls with pin 1 down over first balls that were not fouls.
    let headPin: Ratio?
    /// pinByPin only: the score with every missed single-pin leave made.
    let whatIfScore: Int?
    /// pinByPin only: missed single-pin leaves rewritten.
    let missedSinglePins: Int?
}

struct ExpectedFrame1b: Sendable, Hashable {
    let strikes: Ratio
    let pins: Ratio
}

struct ExpectedReport1b: Sendable {
    let scope: ExpectedReport
    let openFrames: Ratio
    let cleanGames: Ratio
    let firstBallAverage: Ratio
    let headPin: Ratio
    /// Frames 1...10.
    let byFrame: [ExpectedFrame1b]
    let whatIfActual: Ratio
    let whatIfAllMade: Ratio
    let whatIfRewritten: Int
}

extension DemoFixtureExpected {
    static let games1b: [ExpectedGame1b] = [
        // F1 10 / (9, 10) | F2 X (10, 10) | F3 7-10 7 (8, 9 open) | F4 2-8 / (8, 10)
        // F5 F / (foul 0, 10) | F6 X | F7 X | F8 3-6-10 10 (7, 9 open)
        // F9 1-2-10 10 (7, 9 open, pin 1 standing) | F10 X 10 / (10 and 9 on fresh racks;
        // first rack is the strike: 10)
        // First-ball pins 9+10+8+8+0+10+10+7+7+10+9 = 88.
        // Head pin: 11 first balls minus the F5 foul = 10; all but F9 = 9.
        // No missed single pins (both 10s made), so the what-if score stays 162.
        ExpectedGame1b(
            game: .leagueNight1, openFrames: 3, firstBallPins: 88, strikeFrames: [2, 6, 7, 10],
            framePins: [10, 10, 9, 10, 10, 10, 10, 9, 9, 10],
            headPin: Ratio(9, of: 10), whatIfScore: 162, missedSinglePins: 0
        ),
        // F1 X | F2 X | F3 4-5 / (8, 10) | F4 7 - (9, 9 open) | F5 6-10 / (8, 10) | F6 X
        // F7 5 F (9, 9 open) | F8 X | F9 X | F10 X X 10 (10, 10, 9; first rack 10)
        // First-ball pins 10+10+8+9+8+10+9+10+10+10+10+9 = 113. Pin 1 never stands: 12 of 12.
        // What-if: the 7 (F4) and the 5 (F7) become spares. Rescored: F1 10+10+8 = 28
        // | F2 10+8+2 = 20, 48 | F3 10+9 = 19, 67 | F4 10+8 = 18, 85 | F5 10+10 = 20, 105
        // | F6 10+9+1 = 20, 125 | F7 10+10 = 20, 145 | F8 30, 175 | F9 30, 205 | F10 29, 234.
        // Check against 213: F4 +9, F6 +1, F7 +11 = +21.
        ExpectedGame1b(
            game: .leagueNight2, openFrames: 2, firstBallPins: 113, strikeFrames: [1, 2, 6, 8, 9, 10],
            framePins: [10, 10, 10, 9, 10, 10, 9, 10, 10, 10],
            headPin: Ratio(12, of: 12), whatIfScore: 234, missedSinglePins: 2
        ),
        // F1 3-9 / (8, 10) | F2 6-7-10 7 (7, 9 open) | F3 9 / (9, 10) | F4 X
        // F5 1-2-4-10 / (6, 10, pin 1 standing) | F6 2 - (9, 9 open) | F7 X | F8 8 / (9, 10)
        // F9 4-7-10 10 (7, 9 open) | F10 10 / X (9, then 10 on the fresh rack;
        // first rack 9+1 = 10)
        // First-ball pins 8+7+9+10+6+9+10+9+7+9+10 = 94. Head pin: all but F5, 10 of 11.
        // What-if: the 2 (F6) becomes a spare, 10 + F7's strike = 20 instead of 9: 160 + 11
        // = 171. F5's bonus is F6 roll 1, unchanged.
        ExpectedGame1b(
            game: .leagueNight3, openFrames: 3, firstBallPins: 94, strikeFrames: [4, 7],
            framePins: [10, 9, 10, 10, 10, 9, 10, 10, 9, 10],
            headPin: Ratio(10, of: 11), whatIfScore: 171, missedSinglePins: 1
        ),
        // Twelve strikes: no open frame, first-ball pins 12 x 10 = 120,
        // F10 first rack 10.
        ExpectedGame1b(
            game: .tournament1, openFrames: 0, firstBallPins: 120, strikeFrames: Set(1...10),
            framePins: [10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
            headPin: Ratio(12, of: 12), whatIfScore: 300, missedSinglePins: 0
        ),
        // X 9/ 81 X X 72 9/ X 8/ 9-: open F3 F6 F10.
        // First-ball pins 10+9+8+10+10+7+9+10+8+9 = 90.
        ExpectedGame1b(
            game: .tournament2, openFrames: 3, firstBallPins: 90, strikeFrames: [1, 4, 5, 8],
            framePins: [10, 10, 9, 10, 10, 9, 10, 10, 10, 9],
            headPin: nil, whatIfScore: nil, missedSinglePins: nil
        ),
        // 8/ X 9- 7/ X X 81 9/ X XF9: open F3 F7; F10 has a strike, so it is not open.
        // First-ball pins 8+10+9+7+10+10+8+9+10 + F10 10 + foul 0 = 91. F10 first rack is the strike: 10.
        ExpectedGame1b(
            game: .tournament4, openFrames: 2, firstBallPins: 91, strikeFrames: [2, 5, 6, 9, 10],
            framePins: [10, 10, 9, 10, 10, 10, 9, 10, 10, 10],
            headPin: nil, whatIfScore: nil, missedSinglePins: nil
        ),
        // 5/ every frame, 5 fill: clean, first-ball pins 11 x 5 = 55, F10 first rack 5+5 = 10.
        ExpectedGame1b(
            game: .earlyLeague1, openFrames: 0, firstBallPins: 55, strikeFrames: [],
            framePins: [10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
            headPin: nil, whatIfScore: nil, missedSinglePins: nil
        ),
        // F1 X | F2 10 - (9, 9 open) | F3 10 / (9, 10) | F4 5-7 7 (8, 9 open) | F5 X
        // F6 2-4-5 / (7, 10) | F7 7 / (9, 10) | F8 X | F9 10 - (9, 9 open)
        // F10 F / 2-8 (foul 0, then 8 on the fresh rack: 0+10+8 = 18;
        // first rack 0+10 = 10)
        // First-ball pins 10+9+9+8+10+7+9+10+9+0+8 = 89.
        // Head pin: 11 first balls minus the F10 foul = 10; pin 1 never stands: 10 of 10.
        // What-if: the 10s in F2 and F9 become spares. Rescored: F1 10+9+1 = 20
        // | F2 10+9 = 19, 39 | F3 10+8 = 18, 57 | F4 9, 66 | F5 10+3+7 = 20, 86
        // | F6 10+9 = 19, 105 | F7 10+10 = 20, 125 | F8 10+9+1 = 20, 145
        // | F9 10+0 (the foul) = 10, 155 | F10 18, 173.
        // Check against 160: F1 +1, F2 +10, F8 +1, F9 +1 = +13.
        ExpectedGame1b(
            game: .earlyLeague2, openFrames: 3, firstBallPins: 89, strikeFrames: [1, 5, 8],
            framePins: [10, 9, 10, 9, 10, 10, 10, 10, 9, 10],
            headPin: Ratio(10, of: 10), whatIfScore: 173, missedSinglePins: 2
        ),
        // F1 X | F2 10 / (9, 10) | F3 X | F4 7 / (9, 10) | F5 10 - (9, 9 open) | F6 X | F7 X
        // F8 6-7-10 7 (7, 9 open) | F9 3 / (9, 10) | F10 10 / 7 (9, then 9 on the fresh rack: 19;
        // first rack 9+1 = 10)
        // First-ball pins 10+9+10+9+9+10+10+7+9+9+9 = 101. Pin 1 never stands: 11 of 11.
        // What-if: the 10 in F5 becomes a spare, 10 + F6's strike = 20 instead of 9:
        // 181 + 11 = 192. F4's bonus is F5 roll 1, unchanged.
        ExpectedGame1b(
            game: .practice1, openFrames: 2, firstBallPins: 101, strikeFrames: [1, 3, 6, 7],
            framePins: [10, 10, 10, 10, 9, 10, 10, 9, 10, 10],
            headPin: Ratio(11, of: 11), whatIfScore: 192, missedSinglePins: 1
        ),
        // 72 63 X 8/ 9- 81 X X 7/ 81: open F1 F2 F5 F6 F10.
        // First-ball pins 7+6+10+8+9+8+10+10+7+8 = 83.
        ExpectedGame1b(
            game: .practice2, openFrames: 5, firstBallPins: 83, strikeFrames: [3, 7, 8],
            framePins: [9, 9, 10, 10, 9, 9, 10, 10, 10, 9],
            headPin: nil, whatIfScore: nil, missedSinglePins: nil
        ),
        // 9- 81 X 71 9/ 62 X 9/ 81 72: open F1 F2 F4 F6 F9 F10.
        // First-ball pins 9+8+10+7+9+6+10+9+8+7 = 83.
        ExpectedGame1b(
            game: .casualOuting2, openFrames: 6, firstBallPins: 83, strikeFrames: [3, 7],
            framePins: [9, 9, 10, 8, 10, 8, 10, 10, 9, 9],
            headPin: nil, whatIfScore: nil, missedSinglePins: nil
        ),
        // F1 10 / (9, 10) | F2 7 - (9, 9 open) | F3 X | F4 6 / (9, 10) | F5 4 - (9, 9 open)
        // F6 X | F7 10 / (9, 10) | F8 7-10 - (8, 8 open) | F9 X | F10 4 - (9, 9 open)
        // First-ball pins 9+9+10+9+9+10+9+8+10+9 = 92. Pin 1 never stands: 10 of 10.
        // What-if: the 7 (F2), 4 (F5) and 4 (F10) become spares; the 7-10 is a split and
        // stays. F10 gets a fill ball of 0. Rescored: F1 10+9 = 19 | F2 10+10 = 20, 39
        // | F3 10+9+1 = 20, 59 | F4 10+9 = 19, 78 | F5 10+10 = 20, 98 | F6 10+9+1 = 20, 118
        // | F7 10+8 = 18, 136 | F8 8, 144 | F9 10+9+1 = 20, 164 | F10 9+1+0 = 10, 174.
        // Check against 150: F2 +11, F5 +11, F9 +1, F10 +1 = +24.
        ExpectedGame1b(
            game: .friendCasual1, openFrames: 4, firstBallPins: 92, strikeFrames: [3, 6, 9],
            framePins: [10, 9, 10, 10, 9, 10, 10, 8, 10, 9],
            headPin: Ratio(10, of: 10), whatIfScore: 174, missedSinglePins: 3
        ),
        // 81 X 9/ 72 8/ 9- X X 81 9/8: open F1 F4 F6 F9.
        // First-ball pins 8+10+9+7+8+9+10+10+8 + F10 9 + fill 8 = 96. F10 first rack 9+1 = 10.
        ExpectedGame1b(
            game: .friendPractice1, openFrames: 4, firstBallPins: 96, strikeFrames: [2, 7, 8],
            framePins: [9, 10, 10, 9, 10, 9, 10, 10, 9, 10],
            headPin: nil, whatIfScore: nil, missedSinglePins: nil
        ),
        // 7F X 8/ 9- X 9/ 81 7/ 9- 8/X: open F1 (7, then a foul) F4 F7 F9.
        // First-ball pins 7+10+8+9+10+9+8+7+9 + F10 8 + fill 10 = 95. F10 first rack 8+2 = 10.
        ExpectedGame1b(
            game: .friendPractice2, openFrames: 4, firstBallPins: 95, strikeFrames: [2, 5],
            framePins: [7, 10, 10, 9, 10, 10, 9, 10, 9, 10],
            headPin: nil, whatIfScore: nil, missedSinglePins: nil
        ),
    ]

    static func game1b(_ game: DemoGame) -> ExpectedGame1b {
        games1b.first { $0.game == game }!
    }

    // ownerCompetition, 8 rollGames: earlyLeague1 (EL1), earlyLeague2 (EL2),
    // tournament1 (T1), tournament2 (T2), tournament4 (T4), leagueNight1-3 (LN1-3).
    // 5 pinGames: EL2, T1, LN1, LN2, LN3.
    static let ownerCompetition1b = ExpectedReport1b(
        scope: ownerCompetition,
        // EL1 0 + EL2 3 + T1 0 + T2 3 + T4 2 + LN1 3 + LN2 2 + LN3 3 = 16, of 8 x 10 frames
        openFrames: Ratio(16, of: 80),
        cleanGames: Ratio(2, of: 8),                       // EL1 and T1
        // 55 + 89 + 120 + 90 + 91 + 88 + 113 + 94 = 740, over the 89 first balls of 1a
        firstBallAverage: Ratio(740, of: 89),
        // EL2 10/10 + T1 12/12 + LN1 9/10 + LN2 12/12 + LN3 10/11
        headPin: Ratio(53, of: 55),
        // Strikes on roll 1, by frame:
        // F1 EL2 T1 T2 LN2 = 4 | F2 T1 T4 LN1 LN2 = 4 | F3 T1 = 1 | F4 T1 T2 LN3 = 3
        // F5 EL2 T1 T2 T4 = 4 | F6 T1 T4 LN1 LN2 = 4 | F7 T1 LN1 LN3 = 3
        // F8 EL2 T1 T2 LN2 = 4 | F9 T1 T4 LN2 = 3 | F10 T1 T4 LN1 LN2 = 4
        // Sum 34; plus the frame 10 strikes past roll 1 (T1 2, LN2 1, LN3 1) = 38, as in 1a.
        // Pins, in order EL1 EL2 T1 T2 T4 LN1 LN2 LN3:
        // F1 10 10 10 10 10 10 10 10 = 80 | F2 10 9 10 10 10 10 10 9 = 78
        // F3 10 10 10 9 9 9 10 10 = 77    | F4 10 9 10 10 10 10 9 10 = 78
        // F5 10 10 10 10 10 10 10 10 = 80 | F6 10 10 10 9 10 10 10 9 = 78
        // F7 10 10 10 10 9 10 9 10 = 78   | F8 10 10 10 10 10 9 10 10 = 79
        // F9 10 9 10 10 10 9 10 9 = 77    | F10 10 10 10 9 10 10 10 10 = 79
        // F10 is the first rack only: EL1 5/ 10, EL2 F/ 10, T1 X 10, T2 9- 9, T4 X 10,
        // LN1 X 10, LN2 X 10, LN3 10/ 10. It was 160 with fill balls.
        // Check: frames sum to 784 = game totals 100+97+100+97+98+97+98+97.
        byFrame: [
            ExpectedFrame1b(strikes: Ratio(4, of: 8), pins: Ratio(80, of: 8)),
            ExpectedFrame1b(strikes: Ratio(4, of: 8), pins: Ratio(78, of: 8)),
            ExpectedFrame1b(strikes: Ratio(1, of: 8), pins: Ratio(77, of: 8)),
            ExpectedFrame1b(strikes: Ratio(3, of: 8), pins: Ratio(78, of: 8)),
            ExpectedFrame1b(strikes: Ratio(4, of: 8), pins: Ratio(80, of: 8)),
            ExpectedFrame1b(strikes: Ratio(4, of: 8), pins: Ratio(78, of: 8)),
            ExpectedFrame1b(strikes: Ratio(3, of: 8), pins: Ratio(78, of: 8)),
            ExpectedFrame1b(strikes: Ratio(4, of: 8), pins: Ratio(79, of: 8)),
            ExpectedFrame1b(strikes: Ratio(3, of: 8), pins: Ratio(77, of: 8)),
            ExpectedFrame1b(strikes: Ratio(4, of: 8), pins: Ratio(79, of: 8)),
        ],
        // Real: EL2 160 + T1 300 + LN1 162 + LN2 213 + LN3 160 = 995
        whatIfActual: Ratio(995, of: 5),
        // Made: 173 + 300 + 162 + 234 + 171 = 1040
        whatIfAllMade: Ratio(1040, of: 5),
        // EL2 2 + LN2 2 + LN3 1 = 5, the 12 - 7 missed single pins of 1a
        whatIfRewritten: 5
    )

    // ownerAllGames adds practice1 (P1, pinByPin), practice2 (P2) and casualOuting2 (CO2).
    static let ownerAllGames1b = ExpectedReport1b(
        scope: ownerAllGames,
        openFrames: Ratio(29, of: 110),                    // 16 + P1 2 + P2 5 + CO2 6
        cleanGames: Ratio(2, of: 11),
        firstBallAverage: Ratio(1007, of: 120),            // 740 + 101 + 83 + 83
        headPin: Ratio(64, of: 66),                        // 53 + 11, 55 + 11
        // Strikes add P1 F1 F3 F6 F7, P2 F3 F7 F8, CO2 F3 F7:
        // F1 4+1 = 5 | F2 4 | F3 1+3 = 4 | F4 3 | F5 4 | F6 4+1 = 5 | F7 3+3 = 6
        // F8 4+1 = 5 | F9 3 | F10 4. Sum 43 = 47 strikes - 4 past roll 1.
        // Pins add P1, P2, CO2:
        // F1 80+10+9+9 = 108 | F2 78+10+9+9 = 106 | F3 77+10+10+10 = 107
        // F4 78+10+10+8 = 106 | F5 80+9+9+10 = 108 | F6 78+10+9+8 = 105
        // F7 78+10+10+10 = 108 | F8 79+9+10+10 = 108 | F9 77+10+10+9 = 106
        // F10 79+10+9+9 = 107 (P1 10/ 10, P2 81 9, CO2 72 9).
        // Check: 1069 = 784 + 98 + 95 + 92.
        byFrame: [
            ExpectedFrame1b(strikes: Ratio(5, of: 11), pins: Ratio(108, of: 11)),
            ExpectedFrame1b(strikes: Ratio(4, of: 11), pins: Ratio(106, of: 11)),
            ExpectedFrame1b(strikes: Ratio(4, of: 11), pins: Ratio(107, of: 11)),
            ExpectedFrame1b(strikes: Ratio(3, of: 11), pins: Ratio(106, of: 11)),
            ExpectedFrame1b(strikes: Ratio(4, of: 11), pins: Ratio(108, of: 11)),
            ExpectedFrame1b(strikes: Ratio(5, of: 11), pins: Ratio(105, of: 11)),
            ExpectedFrame1b(strikes: Ratio(6, of: 11), pins: Ratio(108, of: 11)),
            ExpectedFrame1b(strikes: Ratio(5, of: 11), pins: Ratio(108, of: 11)),
            ExpectedFrame1b(strikes: Ratio(3, of: 11), pins: Ratio(106, of: 11)),
            ExpectedFrame1b(strikes: Ratio(4, of: 11), pins: Ratio(107, of: 11)),
        ],
        whatIfActual: Ratio(1176, of: 6),                  // 995 + 181
        whatIfAllMade: Ratio(1232, of: 6),                 // 1040 + 192
        whatIfRewritten: 6                                 // 5 + 1, the 17 - 11 of 1a
    )

    // friendAllGames, 3 rollGames: friendPractice1 (FP1), friendPractice2 (FP2),
    // friendCasual1 (FC1, the only pinByPin game).
    static let friendAllGames1b = ExpectedReport1b(
        scope: friendAllGames,
        openFrames: Ratio(12, of: 30),                     // 4 + 4 + 4
        cleanGames: Ratio(0, of: 3),
        firstBallAverage: Ratio(283, of: 32),              // 96 + 95 + 92
        headPin: Ratio(10, of: 10),
        // Strikes FP1 F2 F7 F8, FP2 F2 F5, FC1 F3 F6 F9. Sum 8 = 9 - FP2's F10 fill strike.
        // Pins, in order FP1 FP2 FC1:
        // F1 9 7 10 = 26 | F2 10 10 9 = 29 | F3 10 10 10 = 30 | F4 9 9 10 = 28
        // F5 10 10 9 = 29 | F6 9 10 10 = 29 | F7 10 9 10 = 29 | F8 10 10 8 = 28
        // F9 9 9 10 = 28 | F10 10 10 9 = 29 (FP1 9/ 10, FP2 8/ 10, FC1 4- 9).
        // Check: 285 = 96 + 94 + 95.
        byFrame: [
            ExpectedFrame1b(strikes: Ratio(0, of: 3), pins: Ratio(26, of: 3)),
            ExpectedFrame1b(strikes: Ratio(2, of: 3), pins: Ratio(29, of: 3)),
            ExpectedFrame1b(strikes: Ratio(1, of: 3), pins: Ratio(30, of: 3)),
            ExpectedFrame1b(strikes: Ratio(0, of: 3), pins: Ratio(28, of: 3)),
            ExpectedFrame1b(strikes: Ratio(1, of: 3), pins: Ratio(29, of: 3)),
            ExpectedFrame1b(strikes: Ratio(1, of: 3), pins: Ratio(29, of: 3)),
            ExpectedFrame1b(strikes: Ratio(1, of: 3), pins: Ratio(29, of: 3)),
            ExpectedFrame1b(strikes: Ratio(1, of: 3), pins: Ratio(28, of: 3)),
            ExpectedFrame1b(strikes: Ratio(1, of: 3), pins: Ratio(28, of: 3)),
            ExpectedFrame1b(strikes: Ratio(0, of: 3), pins: Ratio(29, of: 3)),
        ],
        whatIfActual: Ratio(150, of: 1),
        whatIfAllMade: Ratio(174, of: 1),
        whatIfRewritten: 3                                 // the 6 - 3 missed single pins of 1a
    )

    static let reports1b = [ownerCompetition1b, ownerAllGames1b, friendAllGames1b]
}

extension ExpectedReport1b: CustomTestStringConvertible {
    var testDescription: String { scope.testDescription }
}

extension ExpectedGame1b: CustomTestStringConvertible {
    var testDescription: String { "\(game)" }
}
