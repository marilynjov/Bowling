import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct BallMaintenanceRepositoryTests {
    let store: BowlingStore
    var balls: BallRepository { store.balls }
    let ballID: BallID
    let otherBallID: BallID

    static let start = Date(timeIntervalSince1970: 1_790_000_000)

    static func day(_ offset: Double) -> Date {
        start.addingTimeInterval(offset * 86_400)
    }

    init() throws {
        store = try BowlingStore(inMemory: true)
        ballID = try store.balls.addBall(name: "Phaze II", weightPounds: 15, intendedRole: .strike, brand: "Storm").id
        otherBallID = try store.balls.addBall(name: "Spare", weightPounds: 14, intendedRole: .spare, brand: "").id
    }

    /// A one-frame countOnly game in its own session on `day`.
    @discardableResult
    func insert(day offset: Double, defaultBall: BallID?, override: BallID? = nil) throws -> Game {
        try insert(at: Self.day(offset), defaultBall: defaultBall, override: override)
    }

    @discardableResult
    func insert(at sessionDate: Date, defaultBall: BallID?, override: BallID? = nil) throws -> Game {
        let rolls = [
            RollRecord(rollIndex: 1, pinCount: 7, pinsKnown: false),
            RollRecord(rollIndex: 2, pinCount: 2, pinsKnown: false, ballID: override),
        ]
        let record = GameRecord(
            gameIndex: 1, entryMode: .countOnly, defaultBallID: defaultBall, finalScore: 9,
            isComplete: false, frames: [FrameRecord(frameIndex: 1, rolls: rolls)],
            sessionID: SessionID(), sessionDate: sessionDate, eventType: .league
        )
        return try insertGame(record, into: store.context)
    }

    @Test func onlyGamesAfterTheLatestResurfaceCount() throws {
        try insert(day: 1, defaultBall: ballID)
        _ = try balls.logMaintenance(.resurface, date: Self.day(1.5), surfaceGritAfter: "", notes: "", for: ballID)
        try insert(day: 2, defaultBall: ballID)
        _ = try balls.logMaintenance(.resurface, date: Self.day(2.5), surfaceGritAfter: "", notes: "", for: ballID)
        try insert(day: 3, defaultBall: otherBallID, override: ballID)
        _ = try balls.logMaintenance(.polish, date: Self.day(3.5), surfaceGritAfter: "", notes: "", for: ballID)
        try insert(day: 4, defaultBall: ballID)
        try insert(day: 5, defaultBall: otherBallID)
        try store.context.ball(ballID).resurfaceIntervalGames = 2

        let maintenance = try balls.maintenance(for: ballID)
        // Days 1, 2, 4 by default and day 3 by override: 4 games; day 5 is the other ball's.
        #expect(maintenance.gamesBowled == 4)
        // After the day 2.5 resurface (the polish does not reset): days 3 and 4 = 2.
        #expect(maintenance.gamesSinceResurface == 2)
        #expect(maintenance.lastResurface == Self.day(2.5))
        // 2 >= interval 2.
        #expect(maintenance.isResurfaceDue)
        #expect(maintenance.events.map(\.kind) == [.polish, .resurface, .resurface])
    }

    /// Times are built from the start of each day in `timeZone`, so the day 2 game at 1:00
    /// comes before the 23:00 purchase time and only counts because of the start of day,
    /// whatever the machine's time zone.
    @Test(arguments: ["Pacific/Kiritimati", "UTC", "Pacific/Pago_Pago"])
    func withoutAResurfaceGamesCountFromThePurchaseDay(timeZone: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZone))
        balls.calendar = calendar
        func time(day offset: Double, hour: Double) -> Date {
            calendar.startOfDay(for: Self.day(offset)).addingTimeInterval(hour * 3_600)
        }
        try insert(at: time(day: 1, hour: 1), defaultBall: ballID)
        try insert(at: time(day: 2, hour: 1), defaultBall: otherBallID, override: ballID)
        try insert(at: time(day: 3, hour: 1), defaultBall: ballID)
        let ball = try store.context.ball(ballID)
        ball.purchaseDate = time(day: 2, hour: 23)
        ball.resurfaceIntervalGames = 2

        let maintenance = try balls.maintenance(for: ballID)
        // Days 2 and 3 = 2; day 1 came before the purchase. All 3 are games bowled.
        #expect(maintenance.gamesSinceResurface == 2)
        #expect(maintenance.gamesBowled == 3)
        #expect(maintenance.isResurfaceDue)
    }

    /// The Arsenal badge's shortcut must agree with the full calculation at every step.
    @Test func summaryResurfaceDueAgreesWithMaintenance() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        balls.calendar = calendar
        let ball = try store.context.ball(ballID)
        func check() throws {
            let summary = try #require(balls.activeBalls().first { $0.id == ballID })
            #expect(summary.isResurfaceDue == (try balls.maintenance(for: ballID).isResurfaceDue))
        }
        try check()
        ball.resurfaceIntervalGames = 2
        try insert(day: 1, defaultBall: ballID)
        try check()
        try insert(day: 2, defaultBall: otherBallID, override: ballID)
        try check()
        _ = try balls.logMaintenance(.resurface, date: Self.day(2.5), surfaceGritAfter: "", notes: "", for: ballID)
        try check()
        try insert(day: 3, defaultBall: ballID)
        try insert(day: 4, defaultBall: ballID)
        try check()
        _ = try balls.logMaintenance(.polish, date: Self.day(4.5), surfaceGritAfter: "", notes: "", for: ballID)
        try check()
        // A purchase on day 4, after the resurface: only the day 4 game.
        ball.purchaseDate = Self.day(4)
        try check()
        ball.resurfaceIntervalGames = 1
        try check()
        #expect(balls.activeBalls().first { $0.id == ballID }?.isResurfaceDue == true)
    }

    @Test func logMaintenanceSnapshotsGamesAndCopiesTheGrit() throws {
        try insert(day: 1, defaultBall: ballID)
        try insert(day: 2, defaultBall: otherBallID, override: ballID)

        let event = try balls.logMaintenance(.resurface, date: Self.day(3), surfaceGritAfter: "2000 Abralon",
                                             notes: "Pro shop", for: ballID)
        // Day 1 by default, day 2 by override: 2 games at the time.
        #expect(event.gamesOnBallAtTime == 2)
        #expect(event.kind == .resurface)
        #expect(event.notes == "Pro shop")
        #expect(try store.context.ball(ballID).surfaceGrit == "2000 Abralon")
        #expect(try balls.maintenance(for: ballID).events == [event])
    }

    @Test func aBackDatedEventSnapshotsOnlyTheGamesUpToItsDate() throws {
        try insert(day: 1, defaultBall: ballID)
        try insert(day: 2, defaultBall: otherBallID, override: ballID)
        try insert(day: 3, defaultBall: ballID)

        let event = try balls.logMaintenance(.resurface, date: Self.day(2), surfaceGritAfter: "", notes: "", for: ballID)
        // Logged after day 3, dated day 2: days 1 and 2 (session date <= day 2) = 2, not 3.
        #expect(event.gamesOnBallAtTime == 2)
    }

    @Test func theDateDefaultsToNow() throws {
        let before = Date.now
        let event = try balls.logMaintenance(.polish, surfaceGritAfter: "", notes: "", for: ballID)
        #expect((before...Date.now).contains(event.date))
    }

    @Test func aFutureDateIsRefused() throws {
        // A future resurface would be the latest and hold games since resurface at 0.
        let tomorrow = Date.now.addingTimeInterval(86_400)
        #expect(throws: RepositoryError.invalidMaintenance(.dateInFuture)) {
            try balls.logMaintenance(.resurface, date: tomorrow, surfaceGritAfter: "2000 Abralon", notes: "", for: ballID)
        }
        #expect(try balls.maintenance(for: ballID).events.isEmpty)
        #expect(try store.context.ball(ballID).surfaceGrit == "")
    }

    @Test func theUnknownKindIsRefused() throws {
        // .unknown only reads a kind from a newer app version; it is never written.
        #expect(throws: RepositoryError.invalidMaintenance(.unknownKind)) {
            try balls.logMaintenance(.unknown, date: Self.day(1), surfaceGritAfter: "2000 Abralon", notes: "", for: ballID)
        }
        #expect(try balls.maintenance(for: ballID).events.isEmpty)
        #expect(try store.context.ball(ballID).surfaceGrit == "")
    }

    @Test func emptyGritLeavesTheSurfaceAlone() throws {
        try store.context.ball(ballID).surfaceGrit = "3000 polished"
        _ = try balls.logMaintenance(.oilExtraction, date: Self.day(1), surfaceGritAfter: "", notes: "", for: ballID)
        #expect(try store.context.ball(ballID).surfaceGrit == "3000 polished")
    }

    @Test func aBackDatedEventKeepsTheLatestGrit() throws {
        let lastMonth = Date.now.addingTimeInterval(-30 * 86_400)
        _ = try balls.logMaintenance(.resurface, surfaceGritAfter: "2000 Abralon", notes: "", for: ballID)
        _ = try balls.logMaintenance(.polish, date: lastMonth, surfaceGritAfter: "1500 polished", notes: "", for: ballID)
        // The polish is 30 days older than the resurface, so the surface is still 2000.
        #expect(try store.context.ball(ballID).surfaceGrit == "2000 Abralon")
    }

    @Test func noIntervalIsNeverDue() throws {
        try insert(day: 1, defaultBall: ballID)
        let maintenance = try balls.maintenance(for: ballID)
        #expect(maintenance.gamesSinceResurface == 1)
        #expect(maintenance.resurfaceIntervalGames == nil)
        #expect(!maintenance.isResurfaceDue)
    }

    @Test func unknownBallIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try balls.maintenance(for: BallID()) }
        #expect(throws: RepositoryError.notFound) {
            try balls.logMaintenance(.polish, date: Self.day(1), surfaceGritAfter: "", notes: "", for: BallID())
        }
    }

    @Test func unknownStoredKindReadsAsUnknownAndIsPreserved() throws {
        let event = MaintenanceEvent(date: Self.day(1), kind: .other)
        event.kind = "reCore"
        store.context.insert(event)
        event.ball = try store.context.ball(ballID)
        try store.context.save()

        #expect(try balls.maintenance(for: ballID).events.map(\.kind) == [.unknown])
        #expect(event.kind == "reCore")
    }
}
