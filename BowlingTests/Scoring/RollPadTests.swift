import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct RollPadTests {
    /// The next roll's position in a game with `frames` recorded.
    func position(_ mode: EntryMode = .pinByPin, _ frames: [FrameRecord] = []) throws -> RollPosition {
        let game = GameRecord(
            gameIndex: 1, entryMode: mode, finalScore: 0, isComplete: false,
            frames: frames, sessionDate: .now, eventType: .practice
        )
        return try #require(Scorer.nextRoll(in: game))
    }

    func strike(_ index: Int) -> RollRecord {
        RollRecord(rollIndex: index, pinsDown: .all, pinCount: 10, pinsKnown: true)
    }

    func pad(
        _ position: RollPosition, _ mode: EntryMode = .pinByPin,
        tapWhatFell: Bool = false, autoAdvance: Bool = false
    ) -> RollPad {
        RollPad(position: position, entryMode: mode, tapWhatFell: tapWhatFell, autoAdvanceOnSpare: autoAdvance)
    }

    /// Frame 1 after 7 fell, leaving 4, 7 and 10.
    func afterSeven() throws -> RollPosition {
        let down = PinSet(pins: [1, 2, 3, 5, 6, 8, 9])
        return try position(.pinByPin, [
            FrameRecord(frameIndex: 1, rolls: [RollRecord(rollIndex: 1, pinsDown: down, pinCount: 7, pinsKnown: true)]),
        ])
    }

    /// Frames 1–9 open with gutters, so the next roll is in frame 10.
    func gutters() -> [FrameRecord] {
        (1...9).map { frame in
            FrameRecord(frameIndex: frame, rolls: [
                RollRecord(rollIndex: 1, pinCount: 0, pinsKnown: true),
                RollRecord(rollIndex: 2, pinCount: 0, pinsKnown: true),
            ])
        }
    }

    @Test func deckStartsEmptyByDefault() throws {
        let p = pad(try position())
        #expect(p.shown == [])
        #expect(p.nextInput == .pinsLeft([]))
    }

    @Test func deckStartsFullWithTapWhatFell() throws {
        #expect(pad(try position(), tapWhatFell: true).shown == .all)
    }

    @Test func nextRecordsWhatIsShown() throws {
        var p = pad(try position())
        p.setShown(PinSet(pins: [7, 10]))
        #expect(p.nextInput == .pinsLeft(PinSet(pins: [7, 10])))
    }

    @Test func strikeOnlyOnAFreshRack() throws {
        #expect(pad(try position()).offersStrike)

        let tenthAfterStrike = try position(.pinByPin, gutters() + [FrameRecord(frameIndex: 10, rolls: [strike(1)])])
        #expect(tenthAfterStrike.rollIndex == 2)
        #expect(pad(tenthAfterStrike).offersStrike)

        let spare = FrameRecord(frameIndex: 10, rolls: [
            RollRecord(rollIndex: 1, pinsDown: PinSet(pins: [1, 2, 3, 5, 6, 8, 9]), pinCount: 7, pinsKnown: true),
            RollRecord(rollIndex: 2, pinsDown: PinSet(pins: [4, 7, 10]), pinCount: 3, pinsKnown: true),
        ])
        let tenthAfterSpare = try position(.pinByPin, gutters() + [spare])
        #expect(tenthAfterSpare.rollIndex == 3)
        #expect(pad(tenthAfterSpare).offersStrike)

        let second = pad(try afterSeven())
        #expect(!second.offersStrike)
        #expect(second.offersSpare)
    }

    @Test func pinInputs() throws {
        let p = pad(try afterSeven())
        #expect(p.missInput == .pinsLeft(PinSet(pins: [4, 7, 10])))
        #expect(p.spareInput == .pinsLeft([]))
        #expect(pad(try position()).strikeInput == .pinsLeft([]))
    }

    @Test func countSecondBall() throws {
        let afterCountSeven = try position(.countOnly, [
            FrameRecord(frameIndex: 1, rolls: [RollRecord(rollIndex: 1, pinCount: 7, pinsKnown: false)]),
        ])
        let p = pad(afterCountSeven, .countOnly)
        #expect(p.countChoices == 0...3)
        #expect(p.spareInput == .count(3))
        #expect(p.missInput == .count(0))
        #expect(pad(try position(.countOnly), .countOnly).strikeInput == .count(10))
    }

    @Test func autoAdvanceNeedsTapWhatFell() throws {
        var on = pad(try afterSeven(), tapWhatFell: true, autoAdvance: true)
        #expect(!on.autoAdvances)
        on.setShown([])
        #expect(on.autoAdvances)

        var off = pad(try afterSeven(), tapWhatFell: false, autoAdvance: true)
        off.setShown([])
        #expect(!off.autoAdvances)

        var fresh = pad(try position(), tapWhatFell: true, autoAdvance: true)
        fresh.setShown([])
        #expect(!fresh.autoAdvances)
    }
}
