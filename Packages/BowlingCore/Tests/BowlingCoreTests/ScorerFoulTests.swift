import Testing
import BowlingCore

/// §4 "Fouls": a foul scores 0 and the pins are respotted, so the rack is unchanged.
@Suite struct ScorerFoulTests {
    private func card(_ frames: [[Int]]) -> Scorecard {
        Scorer.scorecard(for: countOnlyGame(frames))
    }

    @Test func firstBallFoulThenFullRackIsASpare() {
        let card = card([[F, 10], [5, 0]] + Array(repeating: [0, 0], count: 8))
        #expect(card.frames[0].marks == [.foul, .spare])
        #expect(card.frames[0].runningTotal == 15)
        #expect(card.finalScore == 20)
    }

    @Test func firstBallFoulThenOpen() {
        let card = card([[F, 8]] + Array(repeating: [0, 0], count: 9))
        #expect(card.frames[0].marks == [.foul, .count(8)])
        #expect(card.frames[0].runningTotal == 8)
    }

    @Test func secondBallFoulScoresZeroAndEndsTheFrame() {
        let card = card([[7, F], [3, 0]] + Array(repeating: [0, 0], count: 8))
        #expect(card.frames[0].marks == [.count(7), .foul])
        #expect(card.frames[0].runningTotal == 7)
        #expect(card.finalScore == 10)
    }

    @Test func foulCountsZeroAsAStrikeBonus() {
        let card = card([[10], [F, 10]] + Array(repeating: [0, 0], count: 8))
        #expect(card.frames[0].runningTotal == 20)
        #expect(card.frames[1].runningTotal == 30)
    }

    @Test func foulCountsZeroAsASpareBonus() {
        let card = card([[6, 4], [F, 3]] + Array(repeating: [0, 0], count: 8))
        #expect(card.frames[0].runningTotal == 10)
    }

    struct TenthCase: Sendable, CustomTestStringConvertible {
        let name: String
        let rolls: [Int]
        let marks: [Mark]
        let total: Int
        var testDescription: String { name }
    }

    static let tenth: [TenthCase] = [
        TenthCase(name: "F / X", rolls: [F, 10, 10], marks: [.foul, .spare, .strike], total: 20),
        TenthCase(name: "F 9 open", rolls: [F, 9], marks: [.foul, .count(9)], total: 9),
        TenthCase(name: "7 F open", rolls: [7, F], marks: [.count(7), .foul], total: 7),
        TenthCase(name: "X F /", rolls: [10, F, 10], marks: [.strike, .foul, .spare], total: 20),
        TenthCase(name: "X F 4", rolls: [10, F, 4], marks: [.strike, .foul, .count(4)], total: 14),
        TenthCase(name: "X X F", rolls: [10, 10, F], marks: [.strike, .strike, .foul], total: 20),
        TenthCase(name: "X 6 F", rolls: [10, 6, F], marks: [.strike, .count(6), .foul], total: 16),
        TenthCase(name: "6 / F", rolls: [6, 4, F], marks: [.count(6), .spare, .foul], total: 10),
        TenthCase(name: "F F open", rolls: [F, F], marks: [.foul, .foul], total: 0),
    ]

    @Test(arguments: tenth)
    func foulInTenthFrame(_ c: TenthCase) {
        let card = card(Array(repeating: [0, 0], count: 9) + [c.rolls])
        #expect(card.frames[9].marks == c.marks)
        #expect(card.finalScore == c.total)
    }

    @Test func pinByPinFoulLeavesTheRackStanding() {
        let card = Scorer.scorecard(for: pinByPinGame(
            [[foul, pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)]] + Array(repeating: [pins(), pins()], count: 9)
        ))
        #expect(card.frames[0].marks == [.foul, .spare])
    }
}
