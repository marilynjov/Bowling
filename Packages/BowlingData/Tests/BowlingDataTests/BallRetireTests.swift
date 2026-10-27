import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct BallRetireTests {
    let store: BowlingStore
    var balls: BallRepository { store.balls }

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    @Test func retiringMovesTheBallFromActiveToRetired() throws {
        let kept = try balls.addBall(BallFields(name: "Hy-Road", weightPounds: 15)).id
        let old = try balls.addBall(BallFields(name: "Old Ball", weightPounds: 15)).id
        try balls.setRetired(true, for: old)

        #expect(balls.activeBalls().map(\.id) == [kept])
        #expect(balls.retiredBalls().map(\.id) == [old])
        #expect(try balls.detail(for: old).isRetired)
    }

    @Test func unretiringBringsItBack() throws {
        let id = try balls.addBall(BallFields(name: "Old Ball", weightPounds: 15)).id
        try balls.setRetired(true, for: id)
        try balls.setRetired(false, for: id)

        #expect(balls.activeBalls().map(\.id) == [id])
        #expect(balls.retiredBalls().isEmpty)
        #expect(try !balls.detail(for: id).isRetired)
    }

    @Test func retiredBallsSortByName() throws {
        for name in ["zeta", "Alpha", "beta"] {
            let id = try balls.addBall(BallFields(name: name, weightPounds: 15)).id
            try balls.setRetired(true, for: id)
        }
        #expect(balls.retiredBalls().map(\.name) == ["Alpha", "beta", "zeta"])
    }

    @Test func retiringKeepsTheGamesAndTheirBall() throws {
        let id = try balls.addBall(BallFields(name: "Old Ball", weightPounds: 15)).id
        let record = GameRecord(
            gameIndex: 1, entryMode: .finalOnly, defaultBallID: id, finalScore: 180, isComplete: true,
            frames: [], sessionID: SessionID(), sessionDate: .now, eventType: .league
        )
        let game = try insertGame(record, into: store.context)
        try balls.setRetired(true, for: id)

        #expect(game.defaultBall?.id == id)
        #expect(balls.retiredBalls().first?.gamesBowled == 1)
    }

    @Test func settingTheSameStateLeavesUpdatedAtAlone() throws {
        let id = try balls.addBall(BallFields(name: "Ball", weightPounds: 15)).id
        let before = try store.context.ball(id).updatedAt
        try balls.setRetired(false, for: id)
        #expect(try store.context.ball(id).updatedAt == before)
        try balls.setRetired(true, for: id)
        #expect(try store.context.ball(id).updatedAt > before)
    }

    @Test func unknownBallIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try balls.setRetired(true, for: BallID()) }
    }
}
