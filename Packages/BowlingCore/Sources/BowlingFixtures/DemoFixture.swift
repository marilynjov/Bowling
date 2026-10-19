import Foundation
import BowlingCore

/// Demo data shared by previews, the BowlingData demo store, and StatsEngine tests.
/// Every ID is fixed, so tests and previews can name a game or session directly.
/// Expected stats for these games live in the test targets, not here.
public enum DemoFixture {
    /// 2026-10-14 12:00 UTC. Tests pass this; previews pass `Date.now`.
    public static let referenceDate = Date(timeIntervalSince1970: 1_791_979_200)

    /// Every `DemoGame`, in `DemoGame.allCases` order. Session dates are whole days before
    /// `now` in the Gregorian calendar, so a date preset always selects the same games.
    public static func games(relativeTo now: Date) -> [GameRecord] {
        let calendar = Calendar(identifier: .gregorian)
        return DemoGame.allCases.map { demo in
            let spec = demo.spec
            let session = demo.session
            return GameRecord(
                id: demo.id,
                bowlerID: demo.bowler.id,
                gameIndex: spec.gameIndex,
                entryMode: spec.entryMode,
                defaultBallID: spec.defaultBall?.id,
                finalScore: spec.finalScore,
                isComplete: spec.isComplete,
                frames: spec.frames(),
                sessionID: session.id,
                sessionDate: calendar.date(byAdding: .day, value: -session.daysAgo, to: now)!,
                eventType: session.eventType
            )
        }
    }
}

public enum DemoBowler: Int, CaseIterable, Sendable {
    /// The app's owner, with games in every event type and entry mode.
    case owner = 1
    /// Bowls the league night session with the owner.
    case partner
    /// Only casual and practice games, so their stats fall back to "All games" (§6).
    case friend

    public var id: BowlerID { fixtureID(prefix: "B0", rawValue) }

    public var name: String {
        switch self {
        case .owner: "Sam Rivera"
        case .partner: "Alex Chen"
        case .friend: "Jordan Lee"
        }
    }
}

public enum DemoBall: Int, CaseIterable, Sendable {
    case ownerStrike = 1
    case ownerSpare
    case partnerStrike

    public var id: BallID { fixtureID(prefix: "BA", rawValue) }

    public var owner: DemoBowler {
        switch self {
        case .ownerStrike, .ownerSpare: .owner
        case .partnerStrike: .partner
        }
    }

    public var name: String {
        switch self {
        case .ownerStrike: "Phaze II"
        case .ownerSpare: "Spare Plastic"
        case .partnerStrike: "Hy-Road"
        }
    }

    public var role: BallRole {
        switch self {
        case .ownerStrike, .partnerStrike: .strike
        case .ownerSpare: .spare
        }
    }
}

public enum DemoSession: Int, CaseIterable, Sendable {
    /// Three-game league session bowled by the owner and the partner.
    case leagueNight = 1
    /// Four games, so the owner has both a three- and a four-game series.
    case tournament
    case earlyLeague
    case practice
    case casualOuting
    /// Holds the one incomplete game, for "Resume session".
    case practiceInProgress
    case friendCasual
    case friendPractice

    public var id: SessionID { fixtureID(prefix: "5E", rawValue) }

    public var eventType: EventType {
        switch self {
        case .leagueNight, .earlyLeague: .league
        case .tournament: .tournament
        case .practice, .practiceInProgress, .friendPractice: .practice
        case .casualOuting, .friendCasual: .casual
        }
    }

    /// Spread across the date presets: this week, last 30 days, and older.
    public var daysAgo: Int {
        switch self {
        case .practiceInProgress: 0
        case .leagueNight: 2
        case .friendCasual: 3
        case .practice: 5
        case .tournament: 9
        case .earlyLeague: 16
        case .friendPractice: 20
        case .casualOuting: 40
        }
    }
}

/// Ordered by session, then bowler, then `gameIndex`.
public enum DemoGame: Int, CaseIterable, Sendable {
    case leagueNight1 = 1, leagueNight2, leagueNight3
    case leagueNightPartner1, leagueNightPartner2, leagueNightPartner3
    /// tournament1 is a perfect game.
    case tournament1, tournament2, tournament3, tournament4
    /// earlyLeague1 is all spares (5/ every frame, 150).
    case earlyLeague1, earlyLeague2, earlyLeague3
    case practice1, practice2
    case casualOuting1, casualOuting2
    case practiceInProgress
    case friendCasual1, friendCasual2
    case friendPractice1, friendPractice2

    public var id: GameID { fixtureID(prefix: "6A", rawValue) }

    public var session: DemoSession {
        switch self {
        case .leagueNight1, .leagueNight2, .leagueNight3,
             .leagueNightPartner1, .leagueNightPartner2, .leagueNightPartner3: .leagueNight
        case .tournament1, .tournament2, .tournament3, .tournament4: .tournament
        case .earlyLeague1, .earlyLeague2, .earlyLeague3: .earlyLeague
        case .practice1, .practice2: .practice
        case .casualOuting1, .casualOuting2: .casualOuting
        case .practiceInProgress: .practiceInProgress
        case .friendCasual1, .friendCasual2: .friendCasual
        case .friendPractice1, .friendPractice2: .friendPractice
        }
    }

    public var bowler: DemoBowler {
        switch self {
        case .leagueNightPartner1, .leagueNightPartner2, .leagueNightPartner3: .partner
        case .friendCasual1, .friendCasual2, .friendPractice1, .friendPractice2: .friend
        default: .owner
        }
    }
}

/// A readable fixed UUID: the prefix names the kind, the suffix is the raw value.
func fixtureID(prefix: String, _ number: Int) -> UUID {
    let suffix = String(number, radix: 16, uppercase: true)
    let tail = String(repeating: "0", count: 12 - suffix.count) + suffix
    return UUID(uuidString: "\(prefix)000000-0000-0000-0000-\(tail)")!
}
