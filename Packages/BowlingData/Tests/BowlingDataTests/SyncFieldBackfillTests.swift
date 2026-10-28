import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// Games saved before #48 have `bowlerID` nil and `recordedRollCount` 0; the store fills
/// both when it opens.
@MainActor @Suite struct SyncFieldBackfillTests {
    let store: BowlingStore
    var context: ModelContext { store.context }

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    /// A game as an older build saved it: bowler linked from the Bowler side, so
    /// `bowlerID` was never written, and no stored roll count.
    private func legacyGame(rolls: [Int]) throws -> (game: Game, owner: Bowler) {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        let session = try store.sessions.startSession(
            SessionMetadata(date: DemoFixture.referenceDate, eventType: .practice),
            bowlers: [(owner.id, nil)], entryMode: .countOnly
        )
        let id = try #require(try store.sessions.session(session).bowlers.first?.games.first?.id)
        for count in rolls { _ = try store.games.recordRoll(.count(count), ballID: nil, in: id) }
        let game = try context.game(id)
        let bowler = try context.bowler(owner.id)
        game.assign(nil)
        bowler.games = [game]
        game.recordedRollCount = 0
        game.updatedAt = DemoFixture.referenceDate
        try context.save()
        #expect(game.bowler === bowler && game.bowlerID == nil)
        return (game, bowler)
    }

    @Test func fillsBowlerIDAndRollCountWithoutStamping() throws {
        let (game, owner) = try legacyGame(rolls: [7, 2, 10])

        try store.backfillSyncFields()

        #expect(game.bowlerID == owner.id)
        #expect(game.recordedRollCount == 3)
        #expect(game.updatedAt == DemoFixture.referenceDate)
    }

    @Test func aSecondRunChangesNothing() throws {
        _ = try legacyGame(rolls: [7, 2])
        try store.backfillSyncFields()

        try store.backfillSyncFields()

        #expect(!context.hasChanges)
    }

    @Test func gamesWithoutRollsOrBowlerAreLeftAlone() throws {
        let game = Game(gameIndex: 1, entryMode: .finalOnly)
        context.insert(game)
        try context.save()

        try store.backfillSyncFields()

        #expect(game.bowlerID == nil)
        #expect(game.recordedRollCount == 0)
        #expect(!context.hasChanges)
    }
}
