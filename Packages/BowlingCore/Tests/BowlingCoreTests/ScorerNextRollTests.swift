import Testing
import BowlingCore

@Suite struct ScorerNextRollTests {
    private let zeros = Array(repeating: [0, 0], count: 9)

    private func position(_ frame: Int, _ roll: Int, standing count: Int, fresh: Bool) -> RollPosition {
        RollPosition(frameIndex: frame, rollIndex: roll, standingPins: .all, standingCount: count, isFreshRack: fresh)
    }

    @Test func emptyGameStartsOnAFreshRack() {
        #expect(Scorer.nextRoll(in: countOnlyGame([])) == position(1, 1, standing: 10, fresh: true))
    }

    @Test func secondBallFacesThePinsLeft() {
        #expect(Scorer.nextRoll(in: countOnlyGame([[7]])) == position(1, 2, standing: 3, fresh: false))
    }

    @Test func strikeMovesToTheNextFrame() {
        #expect(Scorer.nextRoll(in: countOnlyGame([[10]])) == position(2, 1, standing: 10, fresh: true))
    }

    @Test func firstBallFoulLeavesTheFullRackAsASpareAttempt() {
        #expect(Scorer.nextRoll(in: countOnlyGame([[F]])) == position(1, 2, standing: 10, fresh: false))
    }

    @Test func pinByPinReportsStandingPins() {
        let next = Scorer.nextRoll(in: pinByPinGame([[pins(1, 2, 3, 5, 6, 8, 9)]]))
        #expect(next?.standingPins == PinSet(pins: [4, 7, 10]))
        #expect(next?.standingCount == 3)
    }

    @Test func tenthStrikeGivesAFreshRack() {
        #expect(Scorer.nextRoll(in: countOnlyGame(zeros + [[10]])) == position(10, 2, standing: 10, fresh: true))
    }

    @Test func tenthDoubleGivesAFreshRack() {
        #expect(Scorer.nextRoll(in: countOnlyGame(zeros + [[10, 10]])) == position(10, 3, standing: 10, fresh: true))
    }

    @Test func tenthStrikeThenCountLeavesThatRack() {
        #expect(Scorer.nextRoll(in: countOnlyGame(zeros + [[10, 7]])) == position(10, 3, standing: 3, fresh: false))
    }

    @Test func tenthSpareGivesAFreshRack() {
        #expect(Scorer.nextRoll(in: countOnlyGame(zeros + [[6, 4]])) == position(10, 3, standing: 10, fresh: true))
    }

    @Test func tenthOpenEndsTheGame() {
        #expect(Scorer.nextRoll(in: countOnlyGame(zeros + [[6, 3]])) == nil)
    }

    @Test func completeGameHasNoNextRoll() {
        #expect(Scorer.nextRoll(in: countOnlyGame(Array(repeating: [10], count: 9) + [[10, 10, 10]])) == nil)
    }

    @Test func finalOnlyHasNoNextRoll() {
        #expect(Scorer.nextRoll(in: game(.finalOnly, [], finalScore: 180)) == nil)
    }
}
