#if DEBUG
import BowlingCore
import Testing
@testable import Bowling

@Suite struct PinDeckTrialTests {
    @Test func startsOnAFreshRack() {
        let trial = PinDeckTrial()
        #expect(trial.position?.frameIndex == 1)
        #expect(trial.position?.rollIndex == 1)
        #expect(trial.position?.standingPins == .all)
    }
    @Test func recordingTheDeckKnocksDownWhatIsNotStanding() {
        var trial = PinDeckTrial()
        trial.record(standing: PinSet(pins: [3, 6, 10]))
        #expect(trial.position?.rollIndex == 2)
        #expect(trial.position?.standingPins == PinSet(pins: [3, 6, 10]))
        #expect(trial.scorecard.frames[0].marks == [.count(7)])
    }
    @Test func strikeClearsTheRackAndMovesToTheNextFrame() {
        var trial = PinDeckTrial()
        trial.clearRack()
        #expect(trial.scorecard.frames[0].marks == [.strike])
        #expect(trial.position?.frameIndex == 2)
    }
    @Test func spareClearsWhatIsLeft() {
        var trial = PinDeckTrial()
        trial.record(standing: .pin10)
        trial.clearRack()
        #expect(trial.scorecard.frames[0].marks == [.count(9), .spare])
    }
    @Test func missKnocksNothingDown() {
        var trial = PinDeckTrial()
        trial.record(standing: .pin7)
        trial.miss()
        #expect(trial.scorecard.frames[0].marks == [.count(9), .gutter])
    }
    @Test func foulCountsZeroAndRespotsThePins() {
        var trial = PinDeckTrial()
        trial.foul()
        #expect(trial.scorecard.frames[0].marks == [.foul])
        #expect(trial.position?.rollIndex == 2)
        #expect(trial.position?.standingPins == .all)
    }
    @Test func undoRemovesTheLastRoll() {
        var trial = PinDeckTrial()
        trial.clearRack()
        trial.record(standing: .pin7)
        trial.undo()
        #expect(trial.position?.frameIndex == 2)
        #expect(trial.position?.rollIndex == 1)
        trial.undo()
        trial.undo()   // nothing left: no crash, still frame 1
        #expect(trial.position?.frameIndex == 1)
    }
    @Test func twelveStrikesFinishAValidPerfectGame() {
        var trial = PinDeckTrial()
        for _ in 0..<12 { trial.clearRack() }
        #expect(trial.position == nil)
        #expect(trial.scorecard.finalScore == 300)
        #expect(Scorer.validate(trial.game).isEmpty)
        trial.clearRack()   // ignored once the game is over
        #expect(trial.scorecard.finalScore == 300)
    }
}
#endif
