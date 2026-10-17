import BowlingCore
import Foundation
import Testing

/// §3.2 MaintenanceEvent derived values. Days are offsets from a fixed date; a game's day
/// is its session date.
@Suite struct BallMaintenanceTests {
    static let start = Date(timeIntervalSince1970: 1_790_000_000)
    static let ball = BallID()
    static let otherBall = BallID()

    static func day(_ offset: Double) -> Date {
        start.addingTimeInterval(offset * 86_400)
    }

    /// A one-frame game: enough to carry a default ball and a roll override.
    static func game(
        day offset: Double, defaultBall: BallID?, rollBalls: [BallID?] = [nil], complete: Bool = true
    ) -> GameRecord {
        let rolls = rollBalls.enumerated().map { index, ball in
            RollRecord(rollIndex: index + 1, pinCount: 0, pinsKnown: false, ballID: ball)
        }
        return GameRecord(
            gameIndex: 1, entryMode: .countOnly, defaultBallID: defaultBall, finalScore: 0,
            isComplete: complete, frames: [FrameRecord(frameIndex: 1, rolls: rolls)],
            sessionID: SessionID(), sessionDate: day(offset), eventType: .league
        )
    }

    static func event(day offset: Double, _ kind: MaintenanceKind) -> MaintenanceRecord {
        MaintenanceRecord(date: day(offset), kind: kind)
    }

    /// g1, g2 before the latest resurface (day 2.5); g3 to g6 after it.
    static let games = [
        game(day: 1, defaultBall: ball),                                  // g1: default
        game(day: 2, defaultBall: ball),                                  // g2: default
        game(day: 3, defaultBall: otherBall, rollBalls: [nil, ball]),     // g3: one override
        game(day: 4, defaultBall: ball, rollBalls: [ball, ball]),         // g4: default and overrides, once
        game(day: 5, defaultBall: otherBall),                             // g5: never uses the ball
        game(day: 6, defaultBall: ball, complete: false),                 // g6: in progress
    ]

    static let events = [
        event(day: 0.5, .resurface),
        event(day: 3.5, .polish),
        event(day: 2.5, .resurface),
        event(day: 4.5, .oilExtraction),
    ]

    @Test func gamesBowledCountsDefaultAndOverrideGamesOnce() {
        let maintenance = BallMaintenance(ball: Self.ball, games: Self.games, events: [], resurfaceIntervalGames: nil)
        // g1, g2 (default), g3 (override), g4 (both, once), g6 (in progress still wears
        // the ball); not g5. 1 + 1 + 1 + 1 + 1 = 5.
        #expect(maintenance.gamesBowled == 5)
    }

    @Test func withoutAResurfaceEveryGameCounts() {
        let polishOnly = [Self.event(day: 0.5, .polish)]
        let maintenance = BallMaintenance(ball: Self.ball, games: Self.games, events: polishOnly, resurfaceIntervalGames: nil)
        // "Since purchase if none": all 5 games bowled.
        #expect(maintenance.gamesSinceResurface == 5)
        #expect(maintenance.lastResurface == nil)
    }

    @Test func onlyGamesAfterTheLatestResurfaceCount() {
        let maintenance = BallMaintenance(ball: Self.ball, games: Self.games, events: Self.events, resurfaceIntervalGames: nil)
        // Latest resurface is day 2.5, not day 0.5; polish (3.5) and oil extraction (4.5)
        // do not reset the count. After 2.5: g3, g4, g6 = 3.
        #expect(maintenance.gamesSinceResurface == 3)
        #expect(maintenance.lastResurface == Self.day(2.5))
    }

    @Test func aGameAtTheResurfaceInstantDoesNotCount() {
        let games = [Self.game(day: 2.5, defaultBall: Self.ball), Self.game(day: 3, defaultBall: Self.ball)]
        let maintenance = BallMaintenance(ball: Self.ball, games: games, events: Self.events, resurfaceIntervalGames: nil)
        // Only the day 3 game is strictly after the day 2.5 resurface: 1.
        #expect(maintenance.gamesSinceResurface == 1)
    }

    /// The date is a full timestamp, not a day: on the day of a session, a resurface at
    /// 2 hours before the session starts counts the session's game, 2 hours after does not.
    @Test(arguments: [(-2.0, 1), (2.0, 0)])
    func aSameDayResurfaceComparesTimes(hoursFromSessionStart: Double, sinceResurface: Int) {
        let games = [Self.game(day: 1, defaultBall: Self.ball)]
        let resurface = MaintenanceRecord(date: Self.day(1).addingTimeInterval(hoursFromSessionStart * 3_600), kind: .resurface)
        let maintenance = BallMaintenance(ball: Self.ball, games: games, events: [resurface], resurfaceIntervalGames: nil)
        #expect(maintenance.gamesSinceResurface == sinceResurface)
    }

    @Test(arguments: [(2, true), (3, true), (4, false)])
    func resurfaceIsDueAtOrPastTheInterval(interval: Int, due: Bool) {
        let maintenance = BallMaintenance(ball: Self.ball, games: Self.games, events: Self.events, resurfaceIntervalGames: interval)
        // 3 games since resurface: due at intervals 2 and 3 (3 >= 3), not at 4.
        #expect(maintenance.isResurfaceDue == due)
    }

    @Test func noIntervalIsNeverDue() {
        let maintenance = BallMaintenance(ball: Self.ball, games: Self.games, events: [], resurfaceIntervalGames: nil)
        #expect(maintenance.gamesSinceResurface == 5)
        #expect(!maintenance.isResurfaceDue)
    }

    @Test func eventsAreNewestFirst() {
        let maintenance = BallMaintenance(ball: Self.ball, games: Self.games, events: Self.events, resurfaceIntervalGames: nil)
        #expect(maintenance.events.map(\.date) == [4.5, 3.5, 2.5, 0.5].map(Self.day))
    }

    @Test func unknownKindDecodesAndNeverCountsAsAResurface() throws {
        let decoded = try JSONDecoder().decode(MaintenanceKind.self, from: Data(#""reCore""#.utf8))
        #expect(decoded == .unknown)
        let events = [MaintenanceRecord(date: Self.day(2.5), kind: decoded)]
        let maintenance = BallMaintenance(ball: Self.ball, games: Self.games, events: events, resurfaceIntervalGames: nil)
        #expect(maintenance.gamesSinceResurface == 5)
    }
}
