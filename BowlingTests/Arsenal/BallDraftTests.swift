import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct BallDraftTests {
    let store: BowlingStore

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    @Test func cantSaveWithoutANameOrWeight() {
        var draft = BallDraft()
        #expect(!draft.canSave)
        draft.name = "Phaze"
        #expect(!draft.canSave)
        draft = BallDraft(weightPounds: 15)
        #expect(!draft.canSave)
        draft.name = "   "
        #expect(!draft.canSave)
        draft.name = "Phaze"
        #expect(draft.canSave)
    }

    @Test func saveAddsTheBallWithEveryField() throws {
        let draft = BallDraft(name: "  Phaze ", brand: "Storm", weightPounds: 15, role: .spare)
        let ball = try draft.save(to: store)
        #expect(ball.name == "Phaze")
        #expect(ball.brand == "Storm")
        #expect(ball.weightPounds == 15)
        #expect(ball.intendedRole == .spare)
        #expect(store.balls.activeBalls().count == 1)
    }

    @Test func savedBallIsInNewSessionsBalls() throws {
        let ball = try BallDraft(name: "Phaze", weightPounds: 15).save(to: store)
        #expect(Available.current(in: store).balls.contains(ball.id))
    }

    @Test func saveWithoutAWeightThrowsAndAddsNothing() {
        #expect(throws: RepositoryError.invalidBall(.weightOutOfRange)) {
            try BallDraft(name: "Phaze").save(to: store)
        }
        #expect(store.balls.activeBalls().isEmpty)
    }
}
