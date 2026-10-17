import Testing
import BowlingCore

/// OQ-3: `FrameScore.leave` is the leave of the frame's spare attempt rack.
@Suite struct ScorerLeaveTests {
    /// A first ball that leaves `standing`.
    private func leaving(_ standing: Int...) -> RollRecord? {
        let down = PinSet.all.subtracting(PinSet(pins: standing))
        return RollRecord(rollIndex: 0, pinsDown: down, pinCount: down.count, pinsKnown: true)
    }

    private func leave(_ standing: Int...) -> Leave {
        LeaveClassifier.classify(PinSet(pins: standing))
    }

    private func leaves(_ frames: [[RollRecord?]]) -> [Leave?] {
        Scorer.scorecard(for: pinByPinGame(frames)).frames.map(\.leave)
    }

    private func tenthLeave(_ rolls: [RollRecord?]) -> Leave? {
        let gutters = Array(repeating: [pins(), pins()], count: 9)
        return leaves(gutters + [rolls])[9]
    }

    @Test func split() {
        let frame = leaves([[leaving(7, 10), pins(7)]])[0]
        #expect(frame == leave(7, 10))
        #expect(frame?.kind == .split)
    }

    @Test func makeableLeave() {
        let frame = leaves([[leaving(3, 6, 10), pins(3, 6, 10)]])[0]
        #expect(frame == leave(3, 6, 10))
        #expect(frame?.kind == .makeable)
    }

    @Test func openFrameKeepsTheLeave() {
        #expect(leaves([[leaving(4, 7, 10), pins(4, 7)]])[0] == leave(4, 7, 10))
    }

    @Test func gutterFirstBallLeavesTheFullRack() {
        #expect(leaves([[pins(), pins(1, 2)]])[0] == leave(1, 2, 3, 4, 5, 6, 7, 8, 9, 10))
    }

    @Test func strikeHasNoLeave() {
        #expect(leaves([[pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)]])[0] == nil)
    }

    @Test func firstBallFoulHasNoLeave() {
        #expect(leaves([[foul, pins(1, 2, 3)]])[0] == nil)
    }

    @Test func secondBallFoulKeepsTheLeave() {
        #expect(leaves([[leaving(10), foul]])[0] == leave(10))
    }

    /// The bowler faces the spare attempt rack as soon as the first ball is in.
    @Test func leaveShowsBeforeTheSpareAttempt() {
        #expect(leaves([[leaving(2, 4, 5, 8)]])[0] == leave(2, 4, 5, 8))
    }

    @Test func unplayedFramesHaveNoLeave() {
        #expect(leaves([[leaving(10), pins(10)]])[1...].allSatisfy { $0 == nil })
    }

    @Test func countOnlyHasNoLeaves() {
        let card = Scorer.scorecard(for: countOnlyGame([[7, 3], [8, 1], [F, 9], [10]]))
        #expect(card.frames.allSatisfy { $0.leave == nil })
    }

    @Test func finalOnlyHasNoLeaves() {
        let card = Scorer.scorecard(for: game(.finalOnly, [], finalScore: 180))
        #expect(card.frames.allSatisfy { $0.leave == nil })
    }

    @Test func pinsUnknownOnTheFirstBallHasNoLeave() {
        var first = leaving(7, 10)!
        first.pinsKnown = false
        #expect(leaves([[first, pins(7)]])[0] == nil)
    }

    // Frame 10: the spare attempt is the first rack a non-strike ball leaves before the
    // frame's last roll; a fill ball's leave is not listed (#57).

    @Test func tenthOpen() {
        #expect(tenthLeave([leaving(6, 10), pins(6)]) == leave(6, 10))
    }

    @Test func tenthSpareThenStrike() {
        #expect(tenthLeave([leaving(10), pins(10), pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)]) == leave(10))
    }

    @Test func tenthSpareThenFillLeave() {
        #expect(tenthLeave([leaving(7, 10), pins(7, 10), leaving(4)]) == leave(7, 10))
    }

    @Test func tenthStrikeThenSpare() {
        #expect(tenthLeave([pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10), leaving(2, 8), pins(2, 8)]) == leave(2, 8))
    }

    @Test func tenthStrikeThenOpen() {
        #expect(tenthLeave([pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10), leaving(4, 6, 7, 10), pins(4)]) == leave(4, 6, 7, 10))
    }

    @Test func tenthThreeStrikes() {
        let strike = pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        #expect(tenthLeave([strike, strike, strike]) == nil)
    }

    @Test func tenthTwoStrikesThenFillLeave() {
        let strike = pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        #expect(tenthLeave([strike, strike, leaving(10)]) == nil)
    }

    @Test func tenthStrikeThenFoulThenSpare() {
        let strike = pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        #expect(tenthLeave([strike, foul, strike]) == nil)
    }

    @Test func tenthFoulThenSpareThenFill() {
        let strike = pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        #expect(tenthLeave([foul, strike, leaving(5)]) == nil)
    }

    @Test func tenthInProgress() {
        let strike = pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        #expect(tenthLeave([leaving(3, 10)]) == leave(3, 10))
        #expect(tenthLeave([leaving(3, 10), pins(3, 10)]) == leave(3, 10))
        #expect(tenthLeave([strike, leaving(5, 7)]) == leave(5, 7))
        #expect(tenthLeave([strike, strike]) == nil)
        #expect(tenthLeave([strike]) == nil)
    }
}
