import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// Spec §8: save after every roll, edit re-validation, and entry mode rules.
@MainActor @Suite struct RollEntryTests {
    let store: BowlingStore
    var games: GameRepository { store.games }
    let owner: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
    }

    private func startGame(_ mode: EntryMode) throws -> GameID {
        let metadata = SessionMetadata(date: DemoFixture.referenceDate, eventType: .practice)
        let session = try store.sessions.startSession(metadata, bowlers: [(owner.id, nil)], entryMode: mode)
        return try #require(try store.sessions.session(session).bowlers.first?.games.first?.id)
    }

    /// Reads through a second context, which sees only what the main context saved.
    private func savedRollCount() throws -> Int {
        try ModelContext(store.container).fetchCount(FetchDescriptor<Roll>())
    }

    private func counts(_ game: GameRecord) -> [[Int]] {
        game.frames.map { $0.rolls.map(\.pinCount) }
    }

    @discardableResult
    private func bowl(_ counts: [Int], in game: GameID) throws -> GameRecord {
        var record = try games.game(game)
        for count in counts { record = try games.recordRoll(.count(count), ballID: nil, in: game) }
        return record
    }

    // MARK: Saving after every roll

    @Test func everyRollIsSavedAsItIsRecorded() throws {
        let game = try startGame(.countOnly)
        for (rolled, count) in [7, 2, 10].enumerated() {
            _ = try games.recordRoll(.count(count), ballID: nil, in: game)
            #expect(try savedRollCount() == rolled + 1)
        }
        let saved = try games.game(game)
        #expect(counts(saved) == [[7, 2], [10]])
        #expect(saved.finalScore == 9)
        #expect(!saved.isComplete)
    }

    @Test func recordRollFillsIndicesAndPinsFromTheEntryMode() throws {
        let game = try startGame(.pinByPin)
        _ = try games.recordRoll(.pins(PinSet(pins: [1, 2, 3, 5, 6, 8, 9])), ballID: nil, in: game)
        let record = try games.recordRoll(.foul, ballID: nil, in: game)

        #expect(record.frames == [FrameRecord(frameIndex: 1, rolls: [
            RollRecord(rollIndex: 1, pinsDown: PinSet(pins: [1, 2, 3, 5, 6, 8, 9]), pinCount: 7, pinsKnown: true),
            RollRecord(rollIndex: 2, pinCount: 0, pinsKnown: true, isFoul: true),
        ])])
    }

    @Test func recordRollStoresTheBallOverride() throws {
        let ball = try store.balls.addBall(name: "Spare", weightPounds: 14, intendedRole: .spare, brand: "")
        let game = try startGame(.countOnly)
        let record = try games.recordRoll(.count(4), ballID: ball.id, in: game)
        #expect(record.frames.first?.rolls.first?.ballID == ball.id)
    }

    @Test func aFullGameCompletesWithItsScore() throws {
        let game = try startGame(.countOnly)
        let record = try bowl(Array(repeating: 10, count: 12), in: game)
        #expect(record.finalScore == 300)
        #expect(record.isComplete)
        #expect(throws: RepositoryError.invalidGame([])) { try games.recordRoll(.count(0), ballID: nil, in: game) }
    }

    @Test func invalidRollIsRefusedAndNothingIsSaved() throws {
        let game = try startGame(.countOnly)
        try bowl([7], in: game)
        #expect(throws: RepositoryError.invalidGame([.pinsExceedAvailable(frameIndex: 1, rollIndex: 2)])) {
            try games.recordRoll(.count(4), ballID: nil, in: game)
        }
        #expect(counts(try games.game(game)) == [[7]])
        #expect(try savedRollCount() == 1)
    }

    @Test func pinsNotStandingAreRefused() throws {
        let game = try startGame(.pinByPin)
        _ = try games.recordRoll(.pins(PinSet(pins: [1, 2, 3])), ballID: nil, in: game)
        #expect(throws: RepositoryError.invalidGame([.notSubsetOfStanding(frameIndex: 1, rollIndex: 2)])) {
            try games.recordRoll(.pins(PinSet(pins: [3, 4])), ballID: nil, in: game)
        }
    }

    @Test func inputForTheOtherModeIsRefused() throws {
        let pinGame = try startGame(.pinByPin)
        let countGame = try startGame(.countOnly)
        let finalGame = try startGame(.finalOnly)
        #expect(throws: RepositoryError.invalidGame([])) { try games.recordRoll(.count(3), ballID: nil, in: pinGame) }
        #expect(throws: RepositoryError.invalidGame([])) { try games.recordRoll(.pins(PinSet(pins: [1])), ballID: nil, in: countGame) }
        #expect(throws: RepositoryError.invalidGame([])) { try games.recordRoll(.foul, ballID: nil, in: finalGame) }
        #expect(try savedRollCount() == 0)
    }

    @Test func recordRollOnMissingGameOrBallIsNotFound() throws {
        let game = try startGame(.countOnly)
        #expect(throws: RepositoryError.notFound) { try games.recordRoll(.count(3), ballID: nil, in: UUID()) }
        #expect(throws: RepositoryError.notFound) { try games.recordRoll(.count(3), ballID: UUID(), in: game) }
        #expect(try savedRollCount() == 0)
    }

    // MARK: Undo

    @Test func undoRemovesTheLastRollAndItsEmptyFrame() throws {
        let game = try startGame(.countOnly)
        try bowl([7, 2, 10, 3], in: game)

        #expect(counts(try games.undoLastRoll(in: game)) == [[7, 2], [10]])
        let undone = try games.undoLastRoll(in: game)
        #expect(counts(undone) == [[7, 2]])
        #expect(undone.finalScore == 9)
        #expect(try savedRollCount() == 2)
    }

    @Test func undoOnAGameWithNoRollsChangesNothing() throws {
        let game = try startGame(.countOnly)
        let started = try games.game(game)
        #expect(try games.undoLastRoll(in: game) == started)
    }

    // MARK: Editing an earlier roll

    @Test func editThatKeepsLaterRollsValidClearsNothing() throws {
        let game = try startGame(.countOnly)
        try bowl([7, 2, 10, 3, 4], in: game)

        let outcome = try games.replaceRoll(frameIndex: 1, rollIndex: 2, with: .count(3), ballID: nil, in: game)
        #expect(outcome.clearedFrames.isEmpty)
        #expect(counts(outcome.game) == [[7, 3], [10], [3, 4]])
        #expect(outcome.game.finalScore == 44)
        #expect(try games.game(game) == outcome.game)
    }

    @Test func editThatInvalidatesALaterRollClearsFromThatRollOnward() throws {
        let game = try startGame(.countOnly)
        try bowl([5, 4, 6, 3, 8, 1], in: game)

        // 8 then 4 is more than ten, so frame 1 roll 2 and everything after it is cleared.
        let outcome = try games.replaceRoll(frameIndex: 1, rollIndex: 1, with: .count(8), ballID: nil, in: game)
        #expect(counts(outcome.game) == [[8]])
        #expect(outcome.clearedFrames == [1, 2, 3])
        #expect(try savedRollCount() == 1)
    }

    @Test func editToAStrikeClearsTheFramesSecondRollAndLaterFrames() throws {
        let game = try startGame(.countOnly)
        try bowl([5, 4, 6, 3], in: game)

        let outcome = try games.replaceRoll(frameIndex: 1, rollIndex: 1, with: .count(10), ballID: nil, in: game)
        #expect(counts(outcome.game) == [[10]])
        #expect(outcome.clearedFrames == [1, 2])
    }

    @Test func editThatReopensAFrameClearsTheFramesAfterIt() throws {
        let game = try startGame(.countOnly)
        try bowl([10, 6, 3, 8, 1], in: game)

        let outcome = try games.replaceRoll(frameIndex: 1, rollIndex: 1, with: .count(7), ballID: nil, in: game)
        #expect(counts(outcome.game) == [[7]])
        #expect(outcome.clearedFrames == [2, 3])
        #expect(Scorer.nextRoll(in: outcome.game)?.frameIndex == 1)
    }

    @Test func pinByPinEditClearsASecondBallThatHitAPinNoLongerStanding() throws {
        let game = try startGame(.pinByPin)
        _ = try games.recordRoll(.pins(PinSet(pins: [1, 2, 3, 5])), ballID: nil, in: game)
        _ = try games.recordRoll(.pins(PinSet(pins: [4, 7])), ballID: nil, in: game)

        let outcome = try games.replaceRoll(
            frameIndex: 1, rollIndex: 1, with: .pins(PinSet(pins: [1, 2, 4, 5])), ballID: nil, in: game
        )
        #expect(outcome.game.frames == [FrameRecord(frameIndex: 1, rolls: [
            RollRecord(rollIndex: 1, pinsDown: PinSet(pins: [1, 2, 4, 5]), pinCount: 4, pinsKnown: true),
        ])])
        #expect(outcome.clearedFrames == [1])
    }

    @Test func editThatIsItselfInvalidIsRefusedAndNothingChanges() throws {
        let game = try startGame(.countOnly)
        let bowled = try bowl([5, 4, 6, 3], in: game)

        #expect(throws: RepositoryError.invalidGame([.pinsExceedAvailable(frameIndex: 1, rollIndex: 2)])) {
            try games.replaceRoll(frameIndex: 1, rollIndex: 2, with: .count(6), ballID: nil, in: game)
        }
        #expect(throws: RepositoryError.invalidGame([])) {
            try games.replaceRoll(frameIndex: 1, rollIndex: 2, with: .pins(.all), ballID: nil, in: game)
        }
        #expect(try games.game(game) == bowled)
    }

    @Test func editOfARollThatDoesNotExistIsNotFound() throws {
        let game = try startGame(.countOnly)
        try bowl([5, 4], in: game)
        #expect(throws: RepositoryError.notFound) {
            try games.replaceRoll(frameIndex: 2, rollIndex: 1, with: .count(3), ballID: nil, in: game)
        }
    }

    @Test func editSetsTheBallOverride() throws {
        let ball = try store.balls.addBall(name: "Spare", weightPounds: 14, intendedRole: .spare, brand: "")
        let game = try startGame(.countOnly)
        try bowl([5, 4], in: game)
        let outcome = try games.replaceRoll(frameIndex: 1, rollIndex: 2, with: .count(4), ballID: ball.id, in: game)
        #expect(outcome.game.frames.first?.rolls.last?.ballID == ball.id)
    }

    // MARK: Entry mode

    @Test func entryModeChangesBeforeTheFirstRoll() throws {
        let game = try startGame(.pinByPin)
        try games.setEntryMode(.countOnly, for: game)
        #expect(try games.game(game).entryMode == .countOnly)
    }

    @Test func entryModeIsLockedAfterTheFirstRoll() throws {
        let game = try startGame(.countOnly)
        let bowled = try bowl([7], in: game)
        #expect(throws: RepositoryError.entryModeLocked) { try games.setEntryMode(.pinByPin, for: game) }
        #expect(try games.game(game) == bowled)
    }

    @Test func saveRefusesAnEntryModeChangeOnAGameWithRolls() throws {
        let game = try startGame(.countOnly)
        var record = try bowl([7], in: game)
        record.entryMode = .pinByPin
        record.frames = []
        #expect(throws: RepositoryError.entryModeLocked) { try games.save(record) }
        #expect(try games.game(game).entryMode == .countOnly)
    }

    @Test func clearingRollsUnlocksTheEntryMode() throws {
        let game = try startGame(.countOnly)
        try bowl([7, 2, 10], in: game)

        let cleared = try games.clearRolls(in: game)
        #expect(cleared.frames.isEmpty)
        #expect(cleared.finalScore == 0)
        #expect(try savedRollCount() == 0)
        try games.setEntryMode(.pinByPin, for: game)
        #expect(try games.game(game).entryMode == .pinByPin)
    }
}
