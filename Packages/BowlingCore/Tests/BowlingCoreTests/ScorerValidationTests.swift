import Testing
import BowlingCore

/// §4 "Validation": `validate` returns every violation, not just the first.
@Suite struct ScorerValidationTests {
    private func roll(_ index: Int, _ count: Int, foul: Bool = false) -> RollRecord {
        RollRecord(rollIndex: index, pinCount: count, pinsKnown: false, isFoul: foul)
    }

    struct Valid: Sendable, CustomTestStringConvertible {
        let name: String
        let frames: [[Int]]
        var testDescription: String { name }
    }

    static let valid: [Valid] = [
        Valid(name: "empty game", frames: []),
        Valid(name: "perfect game", frames: Array(repeating: [10], count: 9) + [[10, 10, 10]]),
        Valid(name: "partial game", frames: [[10], [7, 3], [4]]),
        Valid(name: "tenth X 7 2", frames: Array(repeating: [0, 0], count: 9) + [[10, 7, 2]]),
        Valid(name: "tenth 7 / 9", frames: Array(repeating: [0, 0], count: 9) + [[7, 3, 9]]),
        Valid(name: "tenth 7 2", frames: Array(repeating: [0, 0], count: 9) + [[7, 2]]),
        Valid(name: "first-ball foul then ten", frames: [[F, 10]]),
        Valid(name: "tenth X F ten", frames: Array(repeating: [0, 0], count: 9) + [[10, F, 10]]),
    ]

    @Test(arguments: valid)
    func validGameHasNoErrors(_ c: Valid) {
        #expect(Scorer.validate(countOnlyGame(c.frames)).isEmpty)
    }

    struct Invalid: Sendable, CustomTestStringConvertible {
        let name: String
        let frames: [[Int]]
        let errors: [ScoringError]
        var testDescription: String { name }
    }

    static let invalid: [Invalid] = [
        Invalid(name: "first ball over ten", frames: [[11]],
                errors: [.pinsExceedAvailable(frameIndex: 1, rollIndex: 1)]),
        Invalid(name: "second ball over pins left", frames: [[7, 4]],
                errors: [.pinsExceedAvailable(frameIndex: 1, rollIndex: 2)]),
        Invalid(name: "negative count", frames: [[-2]],
                errors: [.pinsExceedAvailable(frameIndex: 1, rollIndex: 1)]),
        Invalid(name: "second ball after first-ball foul over ten", frames: [[F, 11]],
                errors: [.pinsExceedAvailable(frameIndex: 1, rollIndex: 2)]),
        Invalid(name: "roll after strike", frames: [[10, 0]],
                errors: [.rollAfterStrike(frameIndex: 1)]),
        Invalid(name: "tenth third roll after open", frames: Array(repeating: [0, 0], count: 9) + [[7, 2, 5]],
                errors: [.unearnedThirdRoll]),
        Invalid(name: "tenth fill ball over pins left", frames: Array(repeating: [0, 0], count: 9) + [[10, 7, 4]],
                errors: [.pinsExceedAvailable(frameIndex: 10, rollIndex: 3)]),
        Invalid(name: "tenth second ball over pins left", frames: Array(repeating: [0, 0], count: 9) + [[6, 5]],
                errors: [.pinsExceedAvailable(frameIndex: 10, rollIndex: 2)]),
        Invalid(name: "every violation reported", frames: [[7, 4], [10, 3], [12]],
                errors: [.pinsExceedAvailable(frameIndex: 1, rollIndex: 2), .rollAfterStrike(frameIndex: 2),
                         .pinsExceedAvailable(frameIndex: 3, rollIndex: 1)]),
    ]

    @Test(arguments: invalid)
    func invalidGameReportsEveryError(_ c: Invalid) {
        #expect(Scorer.validate(countOnlyGame(c.frames)) == c.errors)
    }

    @Test func foulWithPinCount() {
        let game = game(.countOnly, [FrameRecord(frameIndex: 1, rolls: [roll(1, 3, foul: true)])])
        #expect(Scorer.validate(game) == [.foulWithPins(frameIndex: 1, rollIndex: 1)])
    }

    @Test func foulWithPinsDown() {
        let roll = RollRecord(rollIndex: 1, pinsDown: .pin1, pinCount: 0, pinsKnown: true, isFoul: true)
        let game = game(.pinByPin, [FrameRecord(frameIndex: 1, rolls: [roll])])
        #expect(Scorer.validate(game) == [.foulWithPins(frameIndex: 1, rollIndex: 1)])
    }

    @Test func secondBallNotSubsetOfStanding() {
        let game = pinByPinGame([[pins(1, 2, 3), pins(3, 4)]])
        #expect(Scorer.validate(game) == [.notSubsetOfStanding(frameIndex: 1, rollIndex: 2)])
    }

    @Test func tenthFillBallNotSubsetOfStanding() {
        let game = pinByPinGame(Array(repeating: [pins(), pins()], count: 9)
            + [[pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10), pins(1, 2, 3), pins(2, 7)]])
        #expect(Scorer.validate(game) == [.notSubsetOfStanding(frameIndex: 10, rollIndex: 3)])
    }

    @Test func tenthFreshRackAcceptsAnyPins() {
        let game = pinByPinGame(Array(repeating: [pins(), pins()], count: 9)
            + [[pins(1, 2, 3), pins(4, 5, 6, 7, 8, 9, 10), pins(1, 2)]])
        #expect(Scorer.validate(game).isEmpty)
    }

    @Test func secondBallAfterFoulMayTakeAnyPin() {
        #expect(Scorer.validate(pinByPinGame([[foul, pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)]])).isEmpty)
    }

    @Test func duplicateFrame() {
        let game = game(.countOnly, [
            FrameRecord(frameIndex: 1, rolls: [roll(1, 10)]),
            FrameRecord(frameIndex: 1, rolls: [roll(1, 10)]),
        ])
        #expect(Scorer.validate(game) == [.duplicateIndex(frameIndex: 1, rollIndex: nil)])
    }

    @Test func duplicateRoll() {
        let game = game(.countOnly, [FrameRecord(frameIndex: 1, rolls: [roll(1, 3), roll(1, 3)])])
        #expect(Scorer.validate(game) == [.duplicateIndex(frameIndex: 1, rollIndex: 1)])
    }

    @Test func framesOutOfOrder() {
        let game = game(.countOnly, [
            FrameRecord(frameIndex: 2, rolls: [roll(1, 10)]),
            FrameRecord(frameIndex: 1, rolls: [roll(1, 10)]),
        ])
        #expect(Scorer.validate(game) == [.outOfOrder(frameIndex: 1)])
    }

    @Test func rollsOutOfOrder() {
        let game = game(.countOnly, [FrameRecord(frameIndex: 1, rolls: [roll(2, 3), roll(1, 4)])])
        #expect(Scorer.validate(game) == [.outOfOrder(frameIndex: 1)])
    }

    @Test func frameIndexOutOfRange() {
        let game = game(.countOnly, [FrameRecord(frameIndex: 11, rolls: [roll(1, 3)])])
        #expect(Scorer.validate(game) == [.outOfOrder(frameIndex: 11)])
    }

    @Test func rollIndexGap() {
        let game = game(.countOnly, [FrameRecord(frameIndex: 1, rolls: [roll(1, 3), roll(3, 4)])])
        #expect(Scorer.validate(game) == [.outOfOrder(frameIndex: 1)])
    }

    @Test func missingFrame() {
        let game = game(.countOnly, [
            FrameRecord(frameIndex: 1, rolls: [roll(1, 10)]),
            FrameRecord(frameIndex: 3, rolls: [roll(1, 10)]),
        ])
        #expect(Scorer.validate(game) == [.outOfOrder(frameIndex: 3)])
    }

    @Test func rollsAfterAnUnfinishedFrame() {
        #expect(Scorer.validate(countOnlyGame([[4], [10]])) == [.outOfOrder(frameIndex: 2)])
    }

    @Test func thirdRollAfterSpareInFramesOneToNine() {
        #expect(Scorer.validate(countOnlyGame([[4, 6, 3]])) == [.outOfOrder(frameIndex: 1)])
    }

    @Test(arguments: [-1, 301])
    func finalOnlyScoreOutOfRange(score: Int) {
        #expect(Scorer.validate(game(.finalOnly, [], finalScore: score)) == [.finalScoreOutOfRange])
    }

    @Test(arguments: [0, 300])
    func finalOnlyScoreInRange(score: Int) {
        #expect(Scorer.validate(game(.finalOnly, [], finalScore: score)).isEmpty)
    }
}
