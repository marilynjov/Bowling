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

    private static func pins(_ rollIndex: Int, _ pins: PinSet) -> RollRecord {
        RollRecord(rollIndex: rollIndex, pinsDown: pins, pinCount: pins.count, pinsKnown: true)
    }

    private func savedGame(_ frames: [FrameRecord], entryMode: EntryMode = .countOnly) throws -> Game {
        let metadata = SessionMetadata(date: base, eventType: .practice)
        let session = try store.sessions.startSession(metadata, bowlers: [(owner.id, nil)], entryMode: entryMode)
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
    private func insertRoll(
        _ rollIndex: Int, pinCount: Int, pinsDown: PinSet? = nil, updatedAt: Date, in frame: Frame, id: UUID = UUID()
    ) -> Roll {
        let roll = Roll(
            rollIndex: rollIndex, pinsDownMask: Int(pinsDown?.rawValue ?? 0), pinCount: pinCount, pinsKnown: pinsDown != nil
        )
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

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))

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
        #expect(game.recordedRollCount == 4)
        #expect(try context.fetchCount(FetchDescriptor<Frame>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Roll>()) == 4)
    }

    /// Frame 3 has not arrived and frame 5 holds a duplicate roll. A full repair would read
    /// frame 4 after an unfinished frame 3 as invalid and clear frames 4 to 6, then sync that
    /// loss everywhere. A game still importing only loses the duplicate row.
    @Test func aGameStillImportingOnlyLosesItsDuplicateRows() throws {
        let game = try savedGame((1...6).map { FrameRecord(frameIndex: $0, rolls: [Self.count(1, 3), Self.count(2, 4)]) })
        #expect(game.recordedRollCount == 12)
        #expect(game.finalScore == 42)
        context.delete(try frame(3, of: game))
        try context.save()
        let duplicate = insertRoll(2, pinCount: 4, updatedAt: base.addingTimeInterval(60), in: try frame(5, of: game))
        try context.save()

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))

        #expect((game.frames ?? []).map(\.frameIndex).sorted() == [1, 2, 4, 5, 6])
        #expect(try frame(5, of: game).rolls?.filter { $0.rollIndex == 2 }.map(\.id) == [duplicate.id])
        #expect(try context.fetchCount(FetchDescriptor<Roll>()) == 10)
        #expect(game.recordedRollCount == 12)
        #expect(game.finalScore == 42)
        #expect(game.updatedAt == base)
    }

    @Test func secondRepairChangesNothing() throws {
        let game = try savedGame()
        insertFrame(2, pins: [6, 3], updatedAt: base.addingTimeInterval(60), in: game)
        try context.save()
        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))
        let repaired = try store.games.game(game.id)
        let updatedAt = game.updatedAt

        #expect(try store.games.repairDuplicates().isEmpty)

        #expect(try store.games.game(game.id) == repaired)
        #expect(game.updatedAt == updatedAt)
        // Frame 1 [7, 2] and frame 2 [6, 3]: 2 frames, 4 rolls.
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

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))

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

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))

        // Cleared from frame 1 roll 2, the first roll that no longer fits; frame 2 goes with it.
        let repaired = try store.games.game(game.id)
        #expect(repaired.frames == [FrameRecord(frameIndex: 1, rolls: [Self.count(1, 8)])])
        #expect(Scorer.validate(repaired).isEmpty)
        // Frame 1 [8] is unfinished, so no frame has a running total yet.
        #expect(repaired.finalScore == 0)
        #expect(!repaired.isComplete)
    }

    @Test func pinByPinRepairWithOverlappingPinsClearsTheSecondRoll() throws {
        let firstSeven: PinSet = [.pin1, .pin2, .pin3, .pin4, .pin5, .pin6, .pin7]
        // Frame 1 [pins 1-7, pins 8 and 9], frame 2 [X]: 7 + 2 = 9, frame 2 waits for its bonus.
        let game = try savedGame([
            FrameRecord(frameIndex: 1, rolls: [Self.pins(1, firstSeven), Self.pins(2, [.pin8, .pin9])]),
            FrameRecord(frameIndex: 2, rolls: [Self.pins(1, .all)]),
        ], entryMode: .pinByPin)
        #expect(game.finalScore == 9)
        // Roll 2 of frame 1, a minute newer: pins 1 and 10, but roll 1 already knocked pin 1 down.
        insertRoll(2, pinCount: 2, pinsDown: [.pin1, .pin10], updatedAt: base.addingTimeInterval(60), in: try frame(1, of: game))
        try context.save()

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))

        // Cleared from frame 1 roll 2, the first roll that no longer fits; frame 2 goes with it.
        let repaired = try store.games.game(game.id)
        #expect(repaired.frames == [FrameRecord(frameIndex: 1, rolls: [Self.pins(1, firstSeven)])])
        #expect(Scorer.validate(repaired).isEmpty)
        // Frame 1 [7] is unfinished, so no frame has a running total yet.
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

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))

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

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))

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

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))

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

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(changed: [game.id]))

        // Frame 1: 7 + 2 = 9; frame 2 waits for its bonus.
        #expect(try store.games.game(game.id).finalScore == 9)
        #expect(game.updatedAt > base)
        #expect(try context.fetchCount(FetchDescriptor<Roll>()) == 3)
    }

    /// A typed score, or one a newer app version computed for a mode this one cannot read,
    /// is never overwritten by rescoring the rows.
    @Test(arguments: ["finalOnly", "aFutureMode"])
    func scoreNotComputedFromRollsIsLeftAlone(entryMode: String) throws {
        let game = try savedGame()
        // The rows alone would score 7 + 2 = 9, not 250.
        game.entryMode = entryMode
        game.finalScore = 250
        game.isComplete = true
        try context.save()

        #expect(try store.games.repairDuplicates().isEmpty)

        #expect(game.finalScore == 250)
        #expect(game.isComplete)
        #expect(game.updatedAt == base)
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

/// §3.4 "Duplicate games": "Next game" on two offline devices syncs back two games for one
/// bowler with one `gameIndex` in a session.
@MainActor @Suite struct DuplicateGameRepairTests {
    let store: BowlingStore
    var context: ModelContext { store.context }
    let session: Session
    let bowler: Bowler
    let base = DemoFixture.referenceDate

    static let smallID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    static let largeID = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!

    init() throws {
        store = try BowlingStore(inMemory: true)
        session = Session(date: DemoFixture.referenceDate)
        bowler = Bowler(name: "Sam", isOwner: true)
        store.context.insert(session)
        store.context.insert(bowler)
    }

    /// A synced countOnly game with `frames` frames of [3, 4], so two recorded rolls per
    /// frame. With `framesArrived` false only the Game row is here, as when CloudKit delivers
    /// it before its Frame and Roll rows.
    @discardableResult
    private func insertGame(
        _ id: UUID, frames: Int, updatedAt: Date, gameIndex: Int = 1, framesArrived: Bool = true,
        in session: Session? = nil, bowler: Bowler? = nil, bowlerID: UUID? = nil, context: ModelContext? = nil
    ) -> Game {
        let context = context ?? self.context
        let game = Game(gameIndex: gameIndex, entryMode: .countOnly)
        game.id = id
        context.insert(game)
        game.session = session ?? self.session
        game.assign(bowler ?? self.bowler)
        if let bowlerID {
            // The bowler's row is gone but the game keeps its ID, as after a Nullify delete.
            let gone = Bowler(name: "Gone")
            gone.id = bowlerID
            context.insert(gone)
            game.assign(gone)
            context.delete(gone)
        }
        game.recordedRollCount = frames * 2
        game.finalScore = frames * 7
        for frameIndex in 1...frames where framesArrived {
            let frame = Frame(frameIndex: frameIndex)
            context.insert(frame)
            frame.game = game
            for (offset, pins) in [3, 4].enumerated() {
                let roll = Roll(rollIndex: offset + 1, pinCount: pins)
                context.insert(roll)
                roll.frame = frame
            }
        }
        game.updatedAt = updatedAt
        return game
    }

    private func gameIDs() throws -> Set<UUID> {
        Set(try context.fetch(FetchDescriptor<Game>()).map(\.id))
    }

    @Test func keepsTheGameWithMoreRolls() throws {
        // The loser is newer and has the smaller ID: roll count decides first.
        insertGame(Self.smallID, frames: 1, updatedAt: base.addingTimeInterval(60))
        insertGame(Self.largeID, frames: 2, updatedAt: base)
        try context.save()

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(deleted: [Self.smallID]))

        #expect(try gameIDs() == [Self.largeID])
        // The loser's frame and rolls cascade; rolls are never merged into the kept game.
        #expect(try context.fetchCount(FetchDescriptor<Frame>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Roll>()) == 4)
    }

    /// Device A holds its own copy with 3 frames and only the Game row of device B's 5-frame
    /// copy. The stored count still ranks B's copy first, and the partial copy is not
    /// rescored to 0 while its rows are on the way.
    @Test func aCopyWithoutItsFramesStillWinsByItsRowCount() throws {
        insertGame(Self.smallID, frames: 3, updatedAt: base.addingTimeInterval(60))
        let kept = insertGame(Self.largeID, frames: 5, updatedAt: base, framesArrived: false)
        try context.save()

        #expect(try store.games.repairDuplicates() == DuplicateRepairResult(deleted: [Self.smallID]))

        #expect(try gameIDs() == [Self.largeID])
        #expect(kept.finalScore == 35)
        #expect(kept.updatedAt == base)
        // The deleted copy's 3 frames cascade.
        #expect(try context.fetchCount(FetchDescriptor<Frame>()) == 0)
    }

    /// Device A lacks device B's Frame rows, device B holds everything: both keep B's copy.
    @Test func devicesMissingDifferentRowsKeepTheSameGame() throws {
        var survivors: Set<UUID> = []
        for bFramesArrived in [false, true] {
            let device = try BowlingStore(inMemory: true)
            let session = Session(date: base)
            let bowler = Bowler(name: "Sam", isOwner: true)
            device.context.insert(session)
            device.context.insert(bowler)
            insertGame(Self.smallID, frames: 3, updatedAt: base.addingTimeInterval(60),
                       in: session, bowler: bowler, context: device.context)
            insertGame(Self.largeID, frames: 5, updatedAt: base, framesArrived: bFramesArrived,
                       in: session, bowler: bowler, context: device.context)
            try device.context.save()

            _ = try device.games.repairDuplicates()

            survivors.formUnion(try device.context.fetch(FetchDescriptor<Game>()).map(\.id))
        }
        #expect(survivors == [Self.largeID])
    }

    /// The deleted copy's frames that were here cascade (see above). One that arrives after
    /// the delete has no game to link to and stays with `game == nil`: no repair deletes it,
    /// since a frame waiting for its Game row looks the same, and nothing but CSV export
    /// reads frames without their game.
    @Test func aFrameArrivingForADeletedGameIsLeftOutOfEveryGame() throws {
        insertGame(Self.smallID, frames: 1, updatedAt: base)
        let kept = insertGame(Self.largeID, frames: 2, updatedAt: base)
        try context.save()
        _ = try store.games.repairDuplicates()
        let late = Frame(frameIndex: 2)
        context.insert(late)
        let roll = Roll(rollIndex: 1, pinCount: 9)
        context.insert(roll)
        roll.frame = late
        try context.save()

        #expect(try store.games.repairDuplicates().isEmpty)

        #expect(late.game == nil)
        #expect(try context.fetchCount(FetchDescriptor<Frame>()) == 3)
        #expect(try store.games.game(Self.largeID).frames.map { $0.rolls.map(\.pinCount) } == [[3, 4], [3, 4]])
        #expect(kept.finalScore == 14)
    }

    @Test func equalRollsKeepTheNewerGame() throws {
        insertGame(Self.smallID, frames: 2, updatedAt: base)
        insertGame(Self.largeID, frames: 2, updatedAt: base.addingTimeInterval(60))
        try context.save()

        _ = try store.games.repairDuplicates()

        #expect(try gameIDs() == [Self.largeID])
    }

    @Test func equalRollsAndTimesKeepTheSmallerID() throws {
        insertGame(Self.largeID, frames: 2, updatedAt: base)
        insertGame(Self.smallID, frames: 2, updatedAt: base)
        try context.save()

        _ = try store.games.repairDuplicates()

        #expect(try gameIDs() == [Self.smallID])
    }

    @Test func secondRepairChangesNothing() throws {
        insertGame(Self.smallID, frames: 1, updatedAt: base)
        insertGame(Self.largeID, frames: 2, updatedAt: base)
        try context.save()
        _ = try store.games.repairDuplicates()
        let kept = try context.game(Self.largeID)
        let updatedAt = kept.updatedAt

        #expect(try store.games.repairDuplicates().isEmpty)

        #expect(try gameIDs() == [Self.largeID])
        #expect(kept.updatedAt == updatedAt)
    }

    /// Both devices run the repair on the same synced rows, received in either order.
    @Test func everyDeviceKeepsTheSameGame() throws {
        var survivors: Set<UUID> = []
        for order in [[Self.smallID, Self.largeID], [Self.largeID, Self.smallID]] {
            let device = try BowlingStore(inMemory: true)
            let session = Session(date: base)
            let bowler = Bowler(name: "Sam", isOwner: true)
            device.context.insert(session)
            device.context.insert(bowler)
            for id in order {
                insertGame(id, frames: 2, updatedAt: base, in: session, bowler: bowler, context: device.context)
            }
            try device.context.save()

            _ = try device.games.repairDuplicates()

            survivors.formUnion(try device.context.fetch(FetchDescriptor<Game>()).map(\.id))
        }
        #expect(survivors == [Self.smallID])
    }

    /// A game whose bowler was deleted elsewhere, or is not imported yet, still matches by
    /// `bowlerID`.
    @Test func bowlerIDMatchesAGameWithoutItsBowler() throws {
        insertGame(Self.smallID, frames: 1, updatedAt: base)
        insertGame(Self.largeID, frames: 2, updatedAt: base, bowlerID: bowler.id)
        try context.save()

        _ = try store.games.repairDuplicates()

        #expect(try gameIDs() == [Self.largeID])
    }

    @Test func differentSlotsAndUnknownBowlersAreKept() throws {
        let other = Bowler(name: "Alex")
        let otherSession = Session(date: base)
        context.insert(other)
        context.insert(otherSession)
        insertGame(UUID(), frames: 1, updatedAt: base)
        insertGame(UUID(), frames: 1, updatedAt: base, gameIndex: 2)
        insertGame(UUID(), frames: 1, updatedAt: base, bowler: other)
        insertGame(UUID(), frames: 1, updatedAt: base, in: otherSession)
        // Two games with no bowler at all: nothing says they are the same bowler's.
        insertGame(UUID(), frames: 1, updatedAt: base).assign(nil)
        insertGame(UUID(), frames: 1, updatedAt: base).assign(nil)
        try context.save()

        _ = try store.games.repairDuplicates()

        #expect(try context.fetchCount(FetchDescriptor<Game>()) == 6)
    }
}
