import Foundation
import BowlingCore

/// Games tagged with centers, leagues, oil patterns, and ball overrides, for the 1b filters
/// (spec §6 "Filters"). A separate collection from `DemoFixture`, so its games, and every 1a
/// expected value computed from them, never change. Bowlers and balls are `DemoBowler` and
/// `DemoBall`.
public enum FilterFixture {
    /// Every `FilterGame`, in `FilterGame.allCases` order. Session dates are whole days
    /// before `now`, as in `DemoFixture`.
    public static func games(relativeTo now: Date) -> [GameRecord] {
        let calendar = Calendar(identifier: .gregorian)
        return FilterGame.allCases.map { game in
            let session = game.session
            return GameRecord(
                id: game.id,
                bowlerID: game.bowler.id,
                gameIndex: game.gameIndex,
                entryMode: game.frames.isEmpty ? .finalOnly : .countOnly,
                defaultBallID: game.defaultBall?.id,
                finalScore: game.finalScore,
                isComplete: true,
                frames: ScoresheetNotation.countOnlyFrames(game.frames, overrideBall: game.overrideBall),
                sessionID: session.id,
                sessionDate: calendar.date(byAdding: .day, value: -session.daysAgo, to: now)!,
                eventType: session.eventType,
                centerID: session.center?.id,
                leagueID: session.league?.id,
                oilPatternID: session.oilPattern?.id
            )
        }
    }
}

public enum FilterCenter: Int, CaseIterable, Sendable {
    case northLanes = 1
    case southBowl

    public var id: CenterID { fixtureID(prefix: "CE", rawValue) }

    public var name: String {
        switch self {
        case .northLanes: "North Lanes"
        case .southBowl: "South Bowl"
        }
    }
}

public enum FilterLeague: Int, CaseIterable, Sendable {
    /// Has season dates, so "this season" uses them.
    case tuesdayMixed = 1
    /// No season dates, so "this season" falls back to the last nine months.
    case sundayDoubles

    public var id: LeagueID { fixtureID(prefix: "1E", rawValue) }

    public var name: String {
        switch self {
        case .tuesdayMixed: "Tuesday Mixed"
        case .sundayDoubles: "Sunday Doubles"
        }
    }

    public var center: FilterCenter {
        switch self {
        case .tuesdayMixed: .northLanes
        case .sundayDoubles: .southBowl
        }
    }

    /// Season start and end as whole days from `now`, negative in the past; nil when unset.
    public var seasonDays: (start: Int, end: Int)? {
        switch self {
        case .tuesdayMixed: (start: -60, end: 120)
        case .sundayDoubles: nil
        }
    }

    public func season(relativeTo now: Date) -> (start: Date, end: Date)? {
        let calendar = Calendar(identifier: .gregorian)
        return seasonDays.map {
            (calendar.date(byAdding: .day, value: $0.start, to: now)!,
             calendar.date(byAdding: .day, value: $0.end, to: now)!)
        }
    }
}

public enum FilterPattern: Int, CaseIterable, Sendable {
    case houseShot = 1
    case cheetah

    public var id: OilPatternID { fixtureID(prefix: "0A", rawValue) }

    public var name: String {
        switch self {
        case .houseShot: "House Shot"
        case .cheetah: "Cheetah"
        }
    }
}

public enum FilterSession: Int, CaseIterable, Sendable {
    /// Tuesday Mixed this week-ish, bowled by the owner and the partner.
    case tuesdayRecent = 1
    /// Tuesday Mixed early in the season, more than 30 days ago.
    case tuesdayOpening
    /// Tuesday Mixed before the season start, but inside the last nine months.
    case tuesdayLastSeason
    case sundayDoubles
    case tournament
    /// No center, league, or pattern.
    case practice

    public var id: SessionID { fixtureID(prefix: "5F", rawValue) }

    public var eventType: EventType {
        switch self {
        case .tuesdayRecent, .tuesdayOpening, .tuesdayLastSeason, .sundayDoubles: .league
        case .tournament: .tournament
        case .practice: .practice
        }
    }

    public var daysAgo: Int {
        switch self {
        case .practice: 1
        case .sundayDoubles: 3
        case .tuesdayRecent: 7
        case .tournament: 12
        case .tuesdayOpening: 50
        case .tuesdayLastSeason: 200
        }
    }

    public var center: FilterCenter? {
        switch self {
        case .tuesdayRecent, .tuesdayOpening, .tuesdayLastSeason: .northLanes
        case .sundayDoubles, .tournament: .southBowl
        case .practice: nil
        }
    }

    public var league: FilterLeague? {
        switch self {
        case .tuesdayRecent, .tuesdayOpening, .tuesdayLastSeason: .tuesdayMixed
        case .sundayDoubles: .sundayDoubles
        case .tournament, .practice: nil
        }
    }

    public var oilPattern: FilterPattern? {
        switch self {
        case .tuesdayRecent, .tuesdayOpening: .houseShot
        case .tuesdayLastSeason, .tournament: .cheetah
        case .sundayDoubles, .practice: nil
        }
    }
}

/// Ordered by session, then bowler, then `gameIndex`. countOnly unless it has no frames
/// (finalOnly); the scores' arithmetic is in the test target's FilterFixtureTests.swift.
public enum FilterGame: Int, CaseIterable, Sendable {
    /// Default strike ball, spare ball on the frame 10 spare.
    case tuesdayRecent1 = 1
    /// Default strike ball only.
    case tuesdayRecent2
    case tuesdayRecentPartner
    case tuesdayOpening1
    /// finalOnly, no ball.
    case tuesdayLastSeason1
    /// No default ball; the spare ball only as a frame 1 override.
    case sundayDoubles1
    /// Default spare ball.
    case tournament1
    /// finalOnly, no ball.
    case practice1

    public var id: GameID { fixtureID(prefix: "6B", rawValue) }

    public var session: FilterSession {
        switch self {
        case .tuesdayRecent1, .tuesdayRecent2, .tuesdayRecentPartner: .tuesdayRecent
        case .tuesdayOpening1: .tuesdayOpening
        case .tuesdayLastSeason1: .tuesdayLastSeason
        case .sundayDoubles1: .sundayDoubles
        case .tournament1: .tournament
        case .practice1: .practice
        }
    }

    public var bowler: DemoBowler {
        self == .tuesdayRecentPartner ? .partner : .owner
    }

    var gameIndex: Int {
        self == .tuesdayRecent2 ? 2 : 1
    }

    var defaultBall: DemoBall? {
        switch self {
        case .tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1: .ownerStrike
        case .tuesdayRecentPartner: .partnerStrike
        case .tournament1: .ownerSpare
        case .tuesdayLastSeason1, .sundayDoubles1, .practice1: nil
        }
    }

    var overrideBall: DemoBall? {
        switch self {
        case .tuesdayRecent1, .sundayDoubles1: .ownerSpare
        default: nil
        }
    }

    /// countOnly ScoresheetNotation, `^` marking a roll thrown with `overrideBall`.
    var frames: [String] {
        let nineCount = Array(repeating: "9-", count: 10)
        switch self {
        case .tuesdayRecent1: return Array(repeating: "9-", count: 9) + ["8/^9"]
        case .sundayDoubles1: return ["9-^"] + Array(repeating: "9-", count: 9)
        case .tuesdayLastSeason1, .practice1: return []
        default: return nineCount
        }
    }

    var finalScore: Int {
        switch self {
        case .tuesdayRecent1: 100
        case .tuesdayLastSeason1: 210
        case .practice1: 175
        default: 90
        }
    }
}
