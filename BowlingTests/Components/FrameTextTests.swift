import BowlingCore
import Testing
@testable import Bowling

@Suite struct FrameTextTests {
    private func text(_ marks: [Mark], frame: Int = 1) -> [String] {
        FrameText.boxes(for: FrameScore(frameIndex: frame, marks: marks, runningTotal: nil))
            .map { $0.map(FrameText.symbol(for:)) ?? "" }
    }

    @Test func symbols() {
        #expect([Mark.strike, .spare, .foul, .gutter, .count(7)].map(FrameText.symbol(for:)) == ["X", "/", "F", "-", "7"])
    }
    @Test func strikeSitsInTheSecondBox() { #expect(text([.strike]) == ["", "X"]) }
    @Test func spareAfterCount() { #expect(text([.count(9), .spare]) == ["9", "/"]) }
    @Test func foulThenCount() { #expect(text([.foul, .count(7)]) == ["F", "7"]) }
    @Test func unbowledFrame() { #expect(text([]) == ["", ""]) }
    @Test func tenthFrameShapes() {
        #expect(text([.strike, .strike, .strike], frame: 10) == ["X", "X", "X"])
        #expect(text([.count(9), .spare, .strike], frame: 10) == ["9", "/", "X"])
        #expect(text([.count(8), .count(1)], frame: 10) == ["8", "1", ""])
    }
    @Test func splitBoxIsTheLeavesFirstBall() {
        let split = LeaveClassifier.classify(PinSet(pins: [7, 10]))
        #expect(FrameText.splitBox(for: FrameScore(frameIndex: 3, marks: [.count(8), .count(1)], leave: split, runningTotal: 50)) == 0)
        #expect(FrameText.splitBox(for: FrameScore(frameIndex: 10, marks: [.strike, .count(8), .count(1)], leave: split, runningTotal: 150)) == 1)
        let makeable = LeaveClassifier.classify(PinSet(pins: [3, 6, 10]))
        #expect(FrameText.splitBox(for: FrameScore(frameIndex: 3, marks: [.count(7), .spare], leave: makeable, runningTotal: 50)) == nil)
    }
    @Test func blankTotalUntilKnown() {
        #expect(FrameText.total(for: FrameScore(frameIndex: 1, marks: [.strike], runningTotal: nil)) == "")
        #expect(FrameText.total(for: FrameScore(frameIndex: 1, marks: [.strike], runningTotal: 20)) == "20")
    }
}
