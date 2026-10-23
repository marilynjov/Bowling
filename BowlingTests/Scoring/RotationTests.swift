import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct RotationTests {
    /// A game of `count` strikes in a row: one per frame through frame 9, then frame 10's
    /// balls.
    func strikes(_ count: Int, _ mode: EntryMode = .pinByPin) -> GameRecord {
        let strike = { (index: Int) in RollRecord(rollIndex: index, pinsDown: .all, pinCount: 10, pinsKnown: true) }
        var frames = (0..<min(count, 9)).map { FrameRecord(frameIndex: $0 + 1, rolls: [strike(1)]) }
        if count > 9 {
            frames.append(FrameRecord(frameIndex: 10, rolls: (1...min(count - 9, 3)).map(strike)))
        }
        return GameRecord(
            gameIndex: 1, entryMode: mode, finalScore: 0, isComplete: false,
            frames: frames, sessionDate: .now, eventType: .practice
        )
    }

    func typed(_ score: Int?) -> GameRecord {
        GameRecord(
            gameIndex: 1, entryMode: .finalOnly, finalScore: score ?? 0, isComplete: score != nil,
            frames: [], sessionDate: .now, eventType: .practice
        )
    }

    @Test func alternatesAfterEachFrame() {
        #expect(Rotation.current(after: 0, games: [strikes(1), strikes(0)], rotates: true) == 1)
        #expect(Rotation.current(after: 1, games: [strikes(1), strikes(1)], rotates: true) == 0)
    }

    @Test func fillBallsStayWithTheBowler() {
        let tenth = strikes(10)
        #expect(Rotation.finishedFrames(tenth) == 9)
        #expect(Rotation.current(after: 0, games: [tenth, strikes(9)], rotates: true) == 0)
    }

    @Test func outOfTurnBowlerFinishesThenFewestIsNext() {
        #expect(Rotation.current(after: 1, games: [strikes(2), strikes(3)], rotates: true) == 0)
    }

    @Test func rotationOffKeepsTheBowlerUntilComplete() {
        #expect(Rotation.current(after: 0, games: [strikes(2), strikes(1)], rotates: false) == 0)
        #expect(Rotation.current(after: 0, games: [strikes(12), strikes(1)], rotates: false) == 1)
    }

    @Test func finalScoreCountsZeroThenTen() {
        #expect(Rotation.finishedFrames(typed(nil)) == 0)
        #expect(!Rotation.isFinished(typed(nil)))
        #expect(Rotation.finishedFrames(typed(180)) == 10)
        #expect(Rotation.isFinished(typed(180)))
    }

    @Test func everyoneFinishedGivesNoBowler() {
        #expect(Rotation.current(after: 0, games: [strikes(12), strikes(12)], rotates: true) == nil)
    }
}
