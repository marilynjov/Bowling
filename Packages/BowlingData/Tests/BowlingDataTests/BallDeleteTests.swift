import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct BallDeleteTests {
    let store: BowlingStore
    var balls: BallRepository { store.balls }
    let ballID: BallID
    let otherBallID: BallID

    init() throws {
        store = try BowlingStore(inMemory: true)
        ballID = try store.balls.addBall(BallFields(name: "Phaze II", weightPounds: 15)).id
        otherBallID = try store.balls.addBall(BallFields(name: "Spare", weightPounds: 14)).id
    }

    /// A one-frame countOnly game.
    @discardableResult
    func insertGame(defaultBall: BallID?, override: BallID? = nil) throws -> Game {
        let rolls = [
            RollRecord(rollIndex: 1, pinCount: 7, pinsKnown: false),
            RollRecord(rollIndex: 2, pinCount: 2, pinsKnown: false, ballID: override),
        ]
        let record = GameRecord(
            gameIndex: 1, entryMode: .countOnly, defaultBallID: defaultBall, finalScore: 9,
            isComplete: false, frames: [FrameRecord(frameIndex: 1, rolls: rolls)],
            sessionID: SessionID(), sessionDate: .now, eventType: .league
        )
        return try BowlingDataTests.insertGame(record, into: store.context)
    }

    func count<T: PersistentModel>(_ type: T.Type) -> Int {
        (try? store.context.fetchCount(FetchDescriptor<T>())) ?? -1
    }

    @Test func anUnusedBallIsDeletedWithItsPhotoAndLog() throws {
        try balls.setPhoto(Data([1]), for: ballID)
        _ = try balls.logMaintenance(.resurface, surfaceGritAfter: "2000", notes: "", for: ballID)
        try balls.deleteBall(ballID)

        #expect(throws: RepositoryError.notFound) { try balls.detail(for: ballID) }
        #expect(balls.activeBalls().map(\.id) == [otherBallID])
        #expect(count(BallPhoto.self) == 0)
        #expect(count(MaintenanceEvent.self) == 0)
    }

    @Test func aRetiredUnusedBallCanBeDeleted() throws {
        try balls.setRetired(true, for: ballID)
        try balls.deleteBall(ballID)
        #expect(balls.retiredBalls().isEmpty)
    }

    @Test func aGamesDefaultBallIsRefused() throws {
        let game = try insertGame(defaultBall: ballID)
        #expect(throws: RepositoryError.ballHasGames(count: 1)) { try balls.deleteBall(ballID) }
        #expect(game.defaultBall?.id == ballID)
    }

    /// The override case is the one nullify would get wrong: the roll's nil ball would read
    /// as the game's default, the other ball.
    @Test func aRollOverrideIsRefusedAndTheRollKeepsItsBall() throws {
        let game = try insertGame(defaultBall: otherBallID, override: ballID)
        #expect(throws: RepositoryError.ballHasGames(count: 1)) { try balls.deleteBall(ballID) }
        let roll = game.frames?.first?.rolls?.first { $0.rollIndex == 2 }
        #expect(roll?.ball?.id == ballID)
        #expect(try balls.detail(for: ballID).gamesBowled == 1)
    }

    @Test func theCountIsGamesEachOnce() throws {
        try insertGame(defaultBall: ballID, override: ballID)
        try insertGame(defaultBall: otherBallID, override: ballID)
        try insertGame(defaultBall: ballID)
        try insertGame(defaultBall: otherBallID)
        // Default and override in one game (1), override only (1), default only (1); the
        // fourth game never uses the ball. 1 + 1 + 1 = 3.
        #expect(throws: RepositoryError.ballHasGames(count: 3)) { try balls.deleteBall(ballID) }
    }

    @Test func aRetiredBallWithGamesIsStillRefused() throws {
        try insertGame(defaultBall: ballID)
        try balls.setRetired(true, for: ballID)
        #expect(throws: RepositoryError.ballHasGames(count: 1)) { try balls.deleteBall(ballID) }
        #expect(balls.retiredBalls().map(\.id) == [ballID])
    }

    @Test func unknownBallIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try balls.deleteBall(BallID()) }
        #expect(balls.activeBalls().count == 2)
    }
}
