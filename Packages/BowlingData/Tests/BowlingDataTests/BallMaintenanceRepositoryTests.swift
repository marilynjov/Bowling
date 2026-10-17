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
        let rolls = [
            RollRecord(rollIndex: 1, pinCount: 7, pinsKnown: false),
            RollRecord(rollIndex: 2, pinCount: 2, pinsKnown: false, ballID: override),
        ]
        let record = GameRecord(
            gameIndex: 1, entryMode: .countOnly, defaultBallID: defaultBall, finalScore: 9,
            isComplete: false, frames: [FrameRecord(frameIndex: 1, rolls: rolls)],
            sessionID: SessionID(), sessionDate: Self.day(offset), eventType: .league
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

    @Test func emptyGritLeavesTheSurfaceAlone() throws {
        try store.context.ball(ballID).surfaceGrit = "3000 polished"
        _ = try balls.logMaintenance(.oilExtraction, date: Self.day(1), surfaceGritAfter: "", notes: "", for: ballID)
        #expect(try store.context.ball(ballID).surfaceGrit == "3000 polished")
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
