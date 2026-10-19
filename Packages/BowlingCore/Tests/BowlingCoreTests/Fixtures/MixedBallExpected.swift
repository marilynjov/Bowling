import BowlingCore
import BowlingFixtures
import Foundation

// Hand-computed values for MixedBallFixture (spec §6 "Ball report", §9 Phase 1b). S is
// DemoBall.ownerStrike, the default ball; P is DemoBall.ownerSpare, the override. Each
// roll's ball is its override if any, else the game's default.
//
// Leave kinds (§5): single pins 1, 6, 7, 8, 9, 10; splits 7-10, 2-7, 3-10 (2-7 and
// 3-10 named in §9); makeable 2-8 and 3-9 (the sleepers, §9).
//
// league1, pinByPin, S default, every spare attempt with P:
//   frame  rolls     pins        score             running
//   1      X         10          10 + 9 + 1  = 20   20
//   2      10 /^     9, 1        10 + 8      = 18   38
//   3      7-10 7^   8, 1        9                  47
//   4      X         10          10 + 8 + 2  = 20   67
//   5      2-8 /^    8, 2        10 + 9      = 19   86
//   6      9 -^      9, 0        9                  95
//   7      X         10          10 + 0 + 10 = 20  115
//   8      F /^      F(0), 10    10 + 8      = 18  133
//   9      3-9 /^    8, 2        10 + 10     = 20  153
//   10     X 10 /^   10, 9, 1    20                173
//   S first balls: frames 1-9 roll 1, frame 10 rolls 1 and 2 = 11.
//     strikes: frames 1, 4, 7, 10.1 = 4.
//     pins: 10+9+8+10+8+9+10+0+8+10+9 = 91.
//     head pin, fouls excluded: 10 non-foul first balls, pin 1 down on all = 10/10.
//   P spare attempts: 2 (10, made), 3 (7-10, missed), 5 (2-8, made), 6 (9, missed),
//     8 (after a foul: no leave, made), 9 (3-9, made), 10 (10, made) = 7, made 5.
//
// league2, pinByPin, S default, every spare attempt with P:
//   1      1 /^      9, 1        10 + 10     = 20   20
//   2      X         10          10 + 8 + 1  = 19   39
//   3      2-7 7^    8, 1        9                  48
//   4      10 /^     9, 1        10 + 10     = 20   68
//   5      X         10          10 + 8 + 0  = 18   86
//   6      3-10 -^   8, 0        8                  94
//   7      7 /^      9, 1        10 + 10     = 20  114
//   8      X         10          10 + 10 + 10 = 30 144
//   9      X         10          10 + 10 + 10 = 30 174
//   10     X X 7     10, 10, 9   29                203
//   S first balls: frames 1-9 roll 1, frame 10 rolls 1, 2, 3 (each on a fresh rack) = 12.
//     The frame 10 roll 3 leaves the 7 but has no roll after it: a first ball, not a
//     spare attempt.
//     strikes: frames 2, 5, 8, 9, 10.1, 10.2 = 6.
//     pins: 9+10+8+9+10+8+9+10+10+10+10+9 = 112.
//     head pin: 12 first balls, no fouls; frame 1 left the head pin = 11/12.
//   P spare attempts: 1 (1, made), 3 (2-7, missed), 4 (10, made), 6 (3-10, missed),
//     7 (7, made) = 5, made 3.
//
// league3, finalOnly, P default: 150. No rolls.
//
// practice1, pinByPin, S default, P overrides the first balls of frames 1 to 4:
//   1      10^ /     9, 1        10 + 9      = 19   19
//   2      9^ -      9, 0        9                  28
//   3      X^        10          10 + 8 + 1  = 19   47
//   4      7-10^ 10  8, 1        9                  56
//   5      X         10          10 + 9 + 1  = 20   76
//   6      8 /       9, 1        10 + 10     = 20   96
//   7      X         10          10 + 10 + 9 = 29  125
//   8      X         10          10 + 9 + 0  = 19  144
//   9      6 -       9, 0        9                 153
//   10     10 / X    9, 1, 10    20                173
//   P first balls: frames 1-4 = 4. strikes: frame 3 = 1. pins: 9+9+10+8 = 36.
//     head pin 4/4.
//   S first balls: frames 5-9 roll 1, frame 10 rolls 1 and 3 = 7.
//     strikes: frames 5, 7, 8, 10.3 = 4. pins: 10+9+10+10+9+9+10 = 67. head pin 7/7.
//   S spare attempts: 1 (10, made), 2 (9, missed), 4 (7-10, missed), 6 (8, made),
//     9 (6, missed), 10 (10, made) = 6, made 3.
//
// practiceInProgress, pinByPin, S default, incomplete: excluded from the report, but it
//   wears the ball (BallMaintenance counts it).
//
// casual1, countOnly, S default, no overrides:
//   1      9/        9, 1        10 + 10     = 20   20
//   2      X         10          10 + 8 + 1  = 19   39
//   3      81        8, 1        9                  48
//   4      X         10          10 + 7 + 2  = 19   67
//   5      72        7, 2        9                  76
//   6      9/        9, 1        10 + 10     = 20   96
//   7      X         10          10 + 10 + 8 = 28  124
//   8      X         10          10 + 8 + 1  = 19  143
//   9      81        8, 1        9                 152
//   10     9/8       9, 1, 8     18                170
//   S first balls: frames 1-9 roll 1, frame 10 rolls 1 and 3 = 11.
//     strikes: frames 2, 4, 7, 8 = 4. pins: 9+10+8+10+7+9+10+10+8+9+8 = 98.
//     No head pin or leaves: countOnly.
//   S spare attempts: 1 (made), 3 (missed), 5 (missed), 6 (made), 9 (missed),
//     10 (made) = 6, made 3. countOnly, so no leave.
//
// casual2, finalOnly, S default: 190. No rolls.
enum MixedBallExpected {
    static let now = DemoFixture.referenceDate

    static func date(_ session: MixedBallSession) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: -session.daysAgo, to: now)!
    }

    struct Condition {
        /// nil is "Other".
        let id: UUID?
        let strikes: Ratio
        let firstBallPins: Ratio
    }

    struct TrendPoint {
        let session: MixedBallSession
        let strikes: Ratio
    }

    struct Leave {
        let name: String
        let made: Int
        let count: Int
    }

    struct Report {
        let ball: DemoBall
        let gamesBowled: Int
        let firstBalls: Int
        let spareAttempts: Int
        let firstUsed: MixedBallSession
        let lastUsed: MixedBallSession
        let strikes: Ratio
        let firstBallAverage: Ratio
        let headPin: Ratio
        let averageAsMainBall: Ratio
        let spares: Ratio
        let singlePinConversion: Ratio
        let splitConversion: Ratio
        let leaves: [Leave]
        let byOilPattern: [Condition]
        let byCenter: [Condition]
        let overTime: [TrendPoint]
    }

    // Complete games using S: league1, league2, practice1, casual1, casual2 = 5.
    static let strikeBall = Report(
        ball: .ownerStrike,
        gamesBowled: 5,
        // 11 + 12 + 7 + 11 = 41.
        firstBalls: 41,
        // league1 0 + league2 0 + practice1 6 + casual1 6 = 12.
        spareAttempts: 12,
        firstUsed: .leagueNight, lastUsed: .casual,
        // 4 + 6 + 4 + 4 = 18 of 41.
        strikes: Ratio(18, of: 41),
        // 91 + 112 + 67 + 98 = 368 over 41.
        firstBallAverage: Ratio(368, of: 41),
        // pinByPin only: 10/10 + 11/12 + 7/7 = 28 of 29.
        headPin: Ratio(28, of: 29),
        // Games with S as the default: 173 + 203 + 173 + 170 + 190 = 909 over 5.
        averageAsMainBall: Ratio(909, of: 5),
        // practice1 3/6 + casual1 3/6 = 6 of 12.
        spares: Ratio(6, of: 12),
        // practice1 only (casual1 is countOnly): 10 made, 9 missed, 8 made, 6 missed,
        // 10 made = 3 of 5.
        singlePinConversion: Ratio(3, of: 5),
        // practice1 7-10 missed = 0 of 1.
        splitConversion: Ratio(0, of: 1),
        // Count descending, then pin numbers ascending: [6] < [7, 10] < [8] < [9].
        leaves: [
            Leave(name: "10", made: 2, count: 2),
            Leave(name: "6", made: 0, count: 1),
            Leave(name: "7-10", made: 0, count: 1),
            Leave(name: "8", made: 1, count: 1),
            Leave(name: "9", made: 0, count: 1),
        ],
        // house (league night): league1 + league2 = 11 + 12 = 23 first balls, strikes
        //   4 + 6 = 10, pins 91 + 112 = 203. 23 >= 10, its own row.
        // sport (practice): 7 first balls < 10, folds into Other.
        // no pattern (casual): folds into Other. Other: 7 + 11 = 18 first balls, strikes
        //   4 + 4 = 8, pins 67 + 98 = 165.
        byOilPattern: [
            Condition(id: MixedBallPattern.house.id, strikes: Ratio(10, of: 23), firstBallPins: Ratio(203, of: 23)),
            Condition(id: nil, strikes: Ratio(8, of: 18), firstBallPins: Ratio(165, of: 18)),
        ],
        // home (league night and casual): 23 + 11 = 34 first balls, strikes 10 + 4 = 14,
        //   pins 203 + 98 = 301.
        // away (practice): 7 < 10, so Other = 7 first balls, 4 strikes, 67 pins.
        byCenter: [
            Condition(id: MixedBallCenter.home.id, strikes: Ratio(14, of: 34), firstBallPins: Ratio(301, of: 34)),
            Condition(id: nil, strikes: Ratio(4, of: 7), firstBallPins: Ratio(67, of: 7)),
        ],
        // Per session, oldest first: league night 10/23, practice 4/7, casual 4/11 (casual2
        // is finalOnly and adds no first balls).
        overTime: [
            TrendPoint(session: .leagueNight, strikes: Ratio(10, of: 23)),
            TrendPoint(session: .practice, strikes: Ratio(4, of: 7)),
            TrendPoint(session: .casual, strikes: Ratio(4, of: 11)),
        ]
    )

    // Complete games using P: league1, league2 (overrides), league3 (default), practice1
    // (overrides) = 4.
    static let spareBall = Report(
        ball: .ownerSpare,
        gamesBowled: 4,
        // practice1 frames 1-4.
        firstBalls: 4,
        // league1 7 + league2 5 = 12.
        spareAttempts: 12,
        firstUsed: .leagueNight, lastUsed: .practice,
        strikes: Ratio(1, of: 4),
        // 9 + 9 + 10 + 8 = 36 over 4.
        firstBallAverage: Ratio(36, of: 4),
        headPin: Ratio(4, of: 4),
        // league3 only: 150 over 1.
        averageAsMainBall: Ratio(150, of: 1),
        // league1 5/7 + league2 3/5 = 8 of 12.
        spares: Ratio(8, of: 12),
        // league1: 10 made, 9 missed, 10 made = 2/3; league2: 1, 10, 7 made = 3/3. 5 of 6.
        singlePinConversion: Ratio(5, of: 6),
        // league1 7-10, league2 2-7 and 3-10, all missed = 0 of 3.
        splitConversion: Ratio(0, of: 3),
        // 10 left 3 times (league1 frames 2 and 10, league2 frame 4), all made. The rest
        // once each, by pin numbers: [1] < [2, 7] < [2, 8] < [3, 9] < [3, 10] < [7]
        // < [7, 10] < [9]. The foul in league1 frame 8 has no leave.
        leaves: [
            Leave(name: "10", made: 3, count: 3),
            Leave(name: "1", made: 1, count: 1),
            Leave(name: "2-7", made: 0, count: 1),
            Leave(name: "2-8", made: 1, count: 1),
            Leave(name: "3-9", made: 1, count: 1),
            Leave(name: "3-10", made: 0, count: 1),
            Leave(name: "7", made: 1, count: 1),
            Leave(name: "7-10", made: 0, count: 1),
            Leave(name: "9", made: 0, count: 1),
        ],
        // All 4 first balls at practice (sport, away): 4 < 10, so only Other.
        byOilPattern: [Condition(id: nil, strikes: Ratio(1, of: 4), firstBallPins: Ratio(36, of: 4))],
        byCenter: [Condition(id: nil, strikes: Ratio(1, of: 4), firstBallPins: Ratio(36, of: 4))],
        // League night has no P first balls, so no point; practice 1/4.
        overTime: [TrendPoint(session: .practice, strikes: Ratio(1, of: 4))]
    )

    // Maintenance of S over every game, the incomplete one included:
    //   games bowled: league1, league2, practice1, practiceInProgress, casual1, casual2 = 6.
    //   resurface 15 days ago, after league night (20) and before practice (10); the polish
    //   8 days ago does not reset. Since: practice1, practiceInProgress, casual1, casual2 = 4.
    //   Interval 4: 4 >= 4, due.
    static let strikeBallGamesBowled = 6
    static let strikeBallGamesSinceResurface = 4
}
