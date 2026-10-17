import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// §3.4 "Duplicate frames or rolls": the rows a two-device offline resume syncs back.
@MainActor @Suite struct DuplicateRepairTests {
    let store: BowlingStore
    var context: ModelContext { store.context }
    let owner: BowlerRecord
    let base = DemoFixture.referenceDate

    init() throws {
        store = try BowlingStore(inMemory: true)
        owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
    }

    private static func count(_ rollIndex: Int, _ pins: Int) -> RollRecord {
        RollRecord(rollIndex: rollIndex, pinCount: pins, pinsKnown: false)
    }

    /// A countOnly game saved as frame 1 [7, 2], frame 2 [X], every row stamped `base`.
    /// Running totals: frame 1 = 7 + 2 = 9; frame 2 waits for its bonus, so the cache is 9.
    private func savedGame() throws -> Game {
        let game = try savedGame([
            FrameRecord(frameIndex: 1, rolls: [Self.count(1, 7), Self.count(2, 2)]),
            FrameRecord(frameIndex: 2, rolls: [Self.count(1, 10)]),
        ])
        #expect(game.finalScore == 9)
        return game
    }

    private func savedGame(_ frames: [FrameRecord]) throws -> Game {
        let metadata = SessionMetadata(date: base, eventType: .practice)
        let session = try store.sessions.startSession(metadata, bowlers: [(owner.id, nil)], entryMode: .countOnly)
        var record = try #require(try store.sessions.session(session).bowlers.first?.games.first)
        record.frames = frames
        _ = try store.games.save(record)
        let game = try context.game(record.id)
        game.updatedAt = base
        for frame in game.frames ?? [] {
            frame.updatedAt = base
            for roll in frame.rolls ?? [] { roll.updatedAt = base }
        }
        try context.save()
        return game
    }

    /// Inserts a synced copy of a frame, the way a remote import does: straight into the model.
    @discardableResult
    private func insertFrame(_ frameIndex: Int, pins: [Int], updatedAt: Date, in game: Game, id: UUID = UUID()) -> Frame {
        let frame = Frame(frameIndex: frameIndex)
        frame.id = id
        frame.updatedAt = updatedAt
        context.insert(frame)
        frame.game = game
        for (offset, count) in pins.enumerated() {
            insertRoll(offset + 1, pinCount: count, updatedAt: updatedAt, in: frame)
        }
        return frame
    }

    @discardableResult
    private func insertRoll(_ rollIndex: Int, pinCount: Int, updatedAt: Date, in frame: Frame, id: UUID = UUID()) -> Roll {
        let roll = Roll(rollIndex: rollIndex, pinCount: pinCount)
        roll.id = id
        roll.updatedAt = updatedAt
        context.insert(roll)
        roll.frame = frame
        return roll
    }

    private func frame(_ frameIndex: Int, of game: Game) throws -> Frame {
        try #require(game.frames?.first { $0.frameIndex == frameIndex })
    }

    @Test func keepsTheNewestFrameAndRollThenValidatesAndScores() throws {
        let game = try savedGame()
        // Frame 2 from the other device, a minute newer: [6, 3] replaces [X].
        let newerFrame = insertFrame(2, pins: [6, 3], updatedAt: base.addingTimeInterval(60), in: game)
        // An older frame 2 loses to both.
        insertFrame(2, pins: [0, 0], updatedAt: base.addingTimeInterval(-60), in: game)
        // Roll 2 of frame 1, a minute newer: 3 replaces 2, making frame 1 a spare.
        let newerRoll = insertRoll(2, pinCount: 3, updatedAt: base.addingTimeInterval(60), in: try frame(1, of: game))
        try context.save()
        #expect(Scorer.validate(game.record()).contains(.duplicateIndex(frameIndex: 2, rollIndex: nil)))
        #expect(Scorer.validate(game.record()).contains(.duplicateIndex(frameIndex: 1, rollIndex: 2)))

        #expect(try store.games.repairDuplicates() == [game.id])

        let repaired = try store.games.game(game.id)
        #expect(repaired.frames == [
            FrameRecord(frameIndex: 1, rolls: [Self.count(1, 7), Self.count(2, 3)]),
            FrameRecord(frameIndex: 2, rolls: [Self.count(1, 6), Self.count(2, 3)]),
        ])
        #expect(try frame(2, of: game).id == newerFrame.id)
        #expect(try frame(1, of: game).rolls?.first { $0.rollIndex == 2 }?.id == newerRoll.id)
        #expect(Scorer.validate(repaired).isEmpty)
        // Frame 1: spare, 10 + next roll 6 = 16. Frame 2: 16 + 6 + 3 = 25. Frame 3 unplayed.
        #expect(repaired.finalScore == 25)
        #expect(!repaired.isComplete)
        #expect(game.updatedAt > base)
        // 2 frames x 2 rolls survive; the losing frames' rolls go with them.
        #expect(try context.fetchCount(FetchDescriptor<Frame>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Roll>()) == 4)
    }

    @Test func frameRankedByItsNewestRollKeepsTheOlderFrameWithNewerRolls() throws {
        let game = try savedGame()
        // Frame 2 stamped a minute older but rolls two minutes newer, as an edit of its rolls
        // written before frames were stamped with them: its newest row is base + 120.
        let olderFrame = insertFrame(2, pins: [6, 3], updatedAt: base.addingTimeInterval(120), in: game)
        olderFrame.updatedAt = base.addingTimeInterval(-60)
        // Frame 2 stamped a minute newer, rolls too: its newest row is base + 60, so it loses.
        insertFrame(2, pins: [0, 0], updatedAt: base.addingTimeInterval(60), in: game)
        try context.save()

        #expect(try store.games.repairDuplicates() == [game.id])

        #expect(try frame(2, of: game).id == olderFrame.id)
        // Frame 1: 7 + 2 = 9. Frame 2: 9 + 6 + 3 = 18.
        #expect(try store.games.game(game.id).finalScore == 18)
    }

    @Test func editingARollStampsItsFrame() throws {
        let game = try savedGame()

        _ = try store.games.replaceRoll(frameIndex: 1, rollIndex: 2, with: .count(3), ballID: nil, in: game.id)

        #expect(try frame(1, of: game).updatedAt > base)
        #expect(try frame(2, of: game).updatedAt == base)
    }

    @Test func invalidRepairInFrame1ClearsFromTheRollThatNoLongerFits() throws {
        // Frame 1 [2, 5], frame 2 [3, 4]: 2 + 5 = 7, 7 + 3 + 4 = 14.
        let game = try savedGame([
            FrameRecord(frameIndex: 1, rolls: [Self.count(1, 2), Self.count(2, 5)]),
            FrameRecord(frameIndex: 2, rolls: [Self.count(1, 3), Self.count(2, 4)]),
        ])
        #expect(game.finalScore == 14)
        // Roll 1 of frame 1, a minute newer: 8 replaces 2, and 8 + 5 = 13 > 10 pins.
        insertRoll(1, pinCount: 8, updatedAt: base.addingTimeInterval(60), in: try frame(1, of: game))
        try context.save()

        #expect(try store.games.repairDuplicates() == [game.id])

        // Cleared from frame 1 roll 2, the first roll that no longer fits; frame 2 goes with it.
        let repaired = try store.games.game(game.id)
        #expect(repaired.frames == [FrameRecord(frameIndex: 1, rolls: [Self.count(1, 8)])])
        #expect(Scorer.validate(repaired).isEmpty)
        // Frame 1 [8] is unfinished, so no frame has a running total yet.
        #expect(repaired.finalScore == 0)
        #expect(!repaired.isComplete)
    }

    @Test func invalidRepairInFrame10ClearsTheUnearnedThirdRoll() throws {
        let opens = (1...9).map { FrameRecord(frameIndex: $0, rolls: [Self.count(1, 0), Self.count(2, 0)]) }
        // Frames 1 to 9 score 0; frame 10 [7, 3, 5] is a spare plus its bonus: 7 + 3 + 5 = 15.
        let game = try savedGame(opens + [
            FrameRecord(frameIndex: 10, rolls: [Self.count(1, 7), Self.count(2, 3), Self.count(3, 5)]),
        ])
        #expect(game.finalScore == 15)
        #expect(game.isComplete)
        // Roll 2 of frame 10, a minute newer: 2 replaces 3, so 7 + 2 is open and roll 3 unearned.
        insertRoll(2, pinCount: 2, updatedAt: base.addingTimeInterval(60), in: try frame(10, of: game))
        try context.save()

        #expect(try store.games.repairDuplicates() == [game.id])

        let repaired = try store.games.game(game.id)
        #expect(repaired.frames == opens + [FrameRecord(frameIndex: 10, rolls: [Self.count(1, 7), Self.count(2, 2)])])
        #expect(Scorer.validate(repaired).isEmpty)
        // 0 + 7 + 2 = 9, and an open frame 10 ends the game.
        #expect(repaired.finalScore == 9)
        #expect(repaired.isComplete)
    }

    @Test func repairThatReopensFrame10ClearsIsComplete() throws {
        let opens = (1...9).map { FrameRecord(frameIndex: $0, rolls: [Self.count(1, 0), Self.count(2, 0)]) }
        // Frames 1 to 9 score 0; an open frame 10 [7, 2] ends the game at 0 + 7 + 2 = 9.
        let game = try savedGame(opens + [FrameRecord(frameIndex: 10, rolls: [Self.count(1, 7), Self.count(2, 2)])])
        #expect(game.finalScore == 9)
        #expect(game.isComplete)
        // Frame 10 from the other device, a minute newer: [X] still owes two bonus rolls.
        insertFrame(10, pins: [10], updatedAt: base.addingTimeInterval(60), in: game)
        try context.save()

        #expect(try store.games.repairDuplicates() == [game.id])

        let repaired = try store.games.game(game.id)
        #expect(!repaired.isComplete)
        // Frame 10 has no running total yet, so the cache is frame 9's: 0.
        #expect(repaired.finalScore == 0)
        #expect(game.updatedAt > base)
    }

    @Test func equalUpdatedAtKeepsTheSmallerUUIDString() throws {
        let game = try savedGame()
        let frame1 = try frame(1, of: game)
        let original = try #require(frame1.rolls?.first { $0.rollIndex == 1 })
        // "00..." sorts before any UUIDString but the nil UUID's own, and "FF..." after every one.
        let smaller = insertRoll(1, pinCount: 8, updatedAt: base, in: frame1, id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")))
        insertRoll(1, pinCount: 1, updatedAt: base, in: frame1, id: try #require(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")))
        try context.save()
        #expect(smaller.id.uuidString < original.id.uuidString)

        #expect(try store.games.repairDuplicates() == [game.id])

        let repaired = try store.games.game(game.id)
        #expect(repaired.frames.first?.rolls == [Self.count(1, 8), Self.count(2, 2)])
        #expect(Scorer.validate(repaired).isEmpty)
        // Frame 1: 8 + 2 = 10, a spare, + next roll X 10 = 20. Frame 2 waits for its bonus.
        #expect(repaired.finalScore == 20)
    }

    @Test func staleCachedScoreIsRescoredWithoutDuplicates() throws {
        let game = try savedGame()
        // A half-imported game: the rows arrived, the cached score did not.
        game.finalScore = 0
        game.updatedAt = base
        try context.save()

        #expect(try store.games.repairDuplicates() == [game.id])

        // Frame 1: 7 + 2 = 9; frame 2 waits for its bonus.
        #expect(try store.games.game(game.id).finalScore == 9)
        #expect(game.updatedAt > base)
        #expect(try context.fetchCount(FetchDescriptor<Roll>()) == 3)
    }

    @Test func gameWithoutDuplicatesIsLeftAlone() throws {
        let game = try savedGame()
        let updatedAt = game.updatedAt

        #expect(try store.games.repairDuplicates().isEmpty)

        #expect(game.updatedAt == updatedAt)
        #expect(try store.games.game(game.id).finalScore == 9)
        #expect(try context.fetchCount(FetchDescriptor<Roll>()) == 3)
    }
}
