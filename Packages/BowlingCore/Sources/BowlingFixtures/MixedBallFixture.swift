import BowlingCore
import Foundation

/// The ball report fixture (spec §9 Phase 1b "Ball report"): the owner throws first balls
/// with `DemoBall.ownerStrike`, the game default, and spare attempts with
/// `DemoBall.ownerSpare`, a per-roll override. A separate collection from `DemoFixture`,
/// so the demo store and the 1a expected values never see it.
///
/// - League night: two pinByPin games, every spare attempt with the spare ball, then a
///   finalOnly game with the spare ball as the default ball.
/// - Practice: the spare ball overrides the first balls of frames 1 to 4, so the strike
///   ball throws the spare attempts there; plus an incomplete game.
/// - Casual: a countOnly game and a finalOnly game, both with the strike ball.
///
/// The strike ball was resurfaced between league night and practice. Frame-by-frame
/// arithmetic is in the test target's MixedBallExpected.swift.
public enum MixedBallFixture {
    /// Every `MixedBallGame`, in `allCases` order, dated like `DemoFixture`.
    public static func games(relativeTo now: Date) -> [GameRecord] {
        let calendar = Calendar(identifier: .gregorian)
        return MixedBallGame.allCases.map { mixed in
            let spec = mixed.spec
            let session = mixed.session
            return GameRecord(
                id: mixed.id,
                bowlerID: DemoBowler.owner.id,
                gameIndex: spec.gameIndex,
                entryMode: spec.entryMode,
                defaultBallID: spec.defaultBall?.id,
                finalScore: spec.finalScore,
                isComplete: spec.isComplete,
                frames: spec.frames(),
                sessionID: session.id,
                sessionDate: calendar.date(byAdding: .day, value: -session.daysAgo, to: now)!,
                eventType: session.eventType,
                centerID: session.center?.id,
                oilPatternID: session.oilPattern?.id
            )
        }
    }

    /// The strike ball's maintenance log: a resurface after league night and a polish after
    /// practice, oldest first.
    public static func strikeBallMaintenance(relativeTo now: Date) -> [MaintenanceRecord] {
        let calendar = Calendar(identifier: .gregorian)
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now)! }
        return [
            MaintenanceRecord(id: fixtureID(prefix: "4E", 1), date: daysAgo(15), kind: .resurface,
                              surfaceGritAfter: "2000 Abralon", gamesOnBallAtTime: 2),
            MaintenanceRecord(id: fixtureID(prefix: "4E", 2), date: daysAgo(8), kind: .polish,
                              surfaceGritAfter: "3000 polished", gamesOnBallAtTime: 4),
        ]
    }

    /// Games since the resurface reach this on the casual night.
    public static let strikeBallResurfaceInterval = 4
}

public enum MixedBallCenter: Int, CaseIterable, Sendable {
    case home = 1
    case away

    public var id: CenterID { fixtureID(prefix: "CD", rawValue) }
}

public enum MixedBallPattern: Int, CaseIterable, Sendable {
    case house = 1
    case sport

    public var id: OilPatternID { fixtureID(prefix: "0B", rawValue) }
}

public enum MixedBallSession: Int, CaseIterable, Sendable {
    case leagueNight = 1
    case practice
    /// Recorded without an oil pattern.
    case casual

    public var id: SessionID { fixtureID(prefix: "5D", rawValue) }

    public var eventType: EventType {
        switch self {
        case .leagueNight: .league
        case .practice: .practice
        case .casual: .casual
        }
    }

    public var daysAgo: Int {
        switch self {
        case .leagueNight: 20
        case .practice: 10
        case .casual: 5
        }
    }

    public var center: MixedBallCenter? {
        switch self {
        case .leagueNight, .casual: .home
        case .practice: .away
        }
    }

    public var oilPattern: MixedBallPattern? {
        switch self {
        case .leagueNight: .house
        case .practice: .sport
        case .casual: nil
        }
    }
}

/// Ordered by session, then `gameIndex`.
public enum MixedBallGame: Int, CaseIterable, Sendable {
    case league1 = 1, league2, league3
    case practice1, practiceInProgress
    case casual1, casual2

    public var id: GameID { fixtureID(prefix: "6C", rawValue) }

    public var session: MixedBallSession {
        switch self {
        case .league1, .league2, .league3: .leagueNight
        case .practice1, .practiceInProgress: .practice
        case .casual1, .casual2: .casual
        }
    }

    // `^` marks a roll thrown with the override ball (ScoresheetNotation).
    var spec: DemoGameSpec {
        switch self {
        case .league1:
            .pinByPin(1, ball: .ownerStrike, score: 173, override: .ownerSpare, [
                "X", "10 /^", "7-10 7^", "X", "2-8 /^",
                "9 -^", "X", "F /^", "3-9 /^", "X 10 /^",
            ])
        case .league2:
            .pinByPin(2, ball: .ownerStrike, score: 203, override: .ownerSpare, [
                "1 /^", "X", "2-7 7^", "10 /^", "X",
                "3-10 -^", "7 /^", "X", "X", "X X 7",
            ])
        case .league3:
            DemoGameSpec(gameIndex: 3, entryMode: .finalOnly, defaultBall: .ownerSpare, finalScore: 150,
                         isComplete: true, scoresheet: [], overrideBall: nil)
        case .practice1:
            .pinByPin(1, ball: .ownerStrike, score: 173, override: .ownerSpare, [
                "10^ /", "9^ -", "X^", "7-10^ 10", "X",
                "8 /", "X", "X", "6 -", "10 / X",
            ])
        case .practiceInProgress:
            // Paused after two strikes: frame 1 still waits for its bonus, so the last
            // known running total is 0 (contract OQ-9).
            .pinByPin(2, ball: .ownerStrike, score: 0, complete: false, ["X", "X"])
        case .casual1:
            .countOnly(1, ball: .ownerStrike, score: 170,
                       ["9/", "X", "81", "X", "72", "9/", "X", "X", "81", "9/8"])
        case .casual2:
            DemoGameSpec(gameIndex: 2, entryMode: .finalOnly, defaultBall: .ownerStrike, finalScore: 190,
                         isComplete: true, scoresheet: [], overrideBall: nil)
        }
    }
}
