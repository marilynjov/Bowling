import Testing
import BowlingCore

@Suite struct ScorerScoreTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let frames: [[Int]]
        let totals: [Int?]
        var testDescription: String { name }
    }

    static let fullGames: [Case] = [
        Case(name: "perfect game", frames: Array(repeating: [10], count: 9) + [[10, 10, 10]],
             totals: [30, 60, 90, 120, 150, 180, 210, 240, 270, 300]),
        Case(name: "all spares with 5 count", frames: Array(repeating: [5, 5], count: 9) + [[5, 5, 5]],
             totals: [15, 30, 45, 60, 75, 90, 105, 120, 135, 150]),
        Case(name: "all gutters", frames: Array(repeating: [0, 0], count: 10),
             totals: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        Case(name: "all nines", frames: Array(repeating: [9, 0], count: 10),
             totals: [9, 18, 27, 36, 45, 54, 63, 72, 81, 90]),
        Case(name: "alternating strikes and spares",
             frames: [[10], [7, 3], [10], [7, 3], [10], [7, 3], [10], [7, 3], [10], [7, 3, 10]],
             totals: [20, 40, 60, 80, 100, 120, 140, 160, 180, 200]),
        Case(name: "alternating spares and strikes",
             frames: [[7, 3], [10], [7, 3], [10], [7, 3], [10], [7, 3], [10], [7, 3], [10, 7, 3]],
             totals: [20, 40, 60, 80, 100, 120, 140, 160, 180, 200]),
    ]

    @Test(arguments: fullGames)
    func fullGame(_ c: Case) {
        let card = Scorer.scorecard(for: countOnlyGame(c.frames))
        #expect(card.frames.map(\.runningTotal) == c.totals)
        #expect(card.finalScore == c.totals.last!)
    }

    static let tenthFrames: [Case] = [
        Case(name: "X X X", frames: [[10, 10, 10]], totals: [30]),
        Case(name: "X X 7", frames: [[10, 10, 7]], totals: [27]),
        Case(name: "X X 0", frames: [[10, 10, 0]], totals: [20]),
        Case(name: "X 7 /", frames: [[10, 7, 3]], totals: [20]),
        Case(name: "X 7 2", frames: [[10, 7, 2]], totals: [19]),
        Case(name: "X 0 /", frames: [[10, 0, 10]], totals: [20]),
        Case(name: "7 / X", frames: [[7, 3, 10]], totals: [20]),
        Case(name: "7 / 5", frames: [[7, 3, 5]], totals: [15]),
        Case(name: "0 / 0", frames: [[0, 10, 0]], totals: [10]),
        Case(name: "7 2 open", frames: [[7, 2]], totals: [9]),
    ]

    @Test(arguments: tenthFrames)
    func tenthFrame(_ c: Case) {
        let frames = Array(repeating: [0, 0], count: 9) + c.frames
        let card = Scorer.scorecard(for: countOnlyGame(frames))
        #expect(card.frames[9].runningTotal == c.totals[0])
        #expect(card.finalScore == c.totals[0])
    }

    static let pending: [Case] = [
        Case(name: "nothing bowled", frames: [], totals: Array(repeating: nil, count: 10)),
        Case(name: "open first ball", frames: [[7]], totals: Array(repeating: nil, count: 10)),
        Case(name: "open frame", frames: [[7, 2]], totals: [9] + Array(repeating: nil, count: 9)),
        Case(name: "spare waits for one roll", frames: [[7, 3]], totals: Array(repeating: nil, count: 10)),
        Case(name: "spare then first ball", frames: [[7, 3], [4]],
             totals: [14] + Array(repeating: nil, count: 9)),
        Case(name: "strike waits for two rolls", frames: [[10], [4]], totals: Array(repeating: nil, count: 10)),
        Case(name: "strike then open", frames: [[10], [4, 5]], totals: [19, 28] + Array(repeating: nil, count: 8)),
        Case(name: "double waits", frames: [[10], [10]], totals: Array(repeating: nil, count: 10)),
        Case(name: "turkey scores the first", frames: [[10], [10], [10]],
             totals: [30] + Array(repeating: nil, count: 9)),
        Case(name: "tenth frame strike waits for its fill balls",
             frames: Array(repeating: [0, 0], count: 9) + [[10, 10]],
             totals: Array(repeating: 0, count: 9) + [nil]),
        Case(name: "tenth frame spare waits for its fill ball",
             frames: Array(repeating: [0, 0], count: 9) + [[6, 4]],
             totals: Array(repeating: 0, count: 9) + [nil]),
    ]

    @Test(arguments: pending)
    func pendingRunningTotals(_ c: Case) {
        let card = Scorer.scorecard(for: countOnlyGame(c.frames))
        #expect(card.frames.map(\.frameIndex) == Array(1...10))
        #expect(card.frames.map(\.runningTotal) == c.totals)
        #expect(card.finalScore == nil)
    }

    @Test func pinByPinScoresLikeCountOnly() {
        let frame: [RollRecord?] = [pins(1, 2, 3, 4, 5, 6, 7, 8, 9), pins(10)]
        let card = Scorer.scorecard(for: pinByPinGame(Array(repeating: frame, count: 9)
            + [[pins(1, 2, 3, 4, 5, 6, 7, 8, 9), pins(10), pins(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)]]))
        #expect(card.finalScore == 191)
    }

    @Test func finalOnlyUsesTypedScore() {
        let card = Scorer.scorecard(for: game(.finalOnly, [], finalScore: 212))
        #expect(card.finalScore == 212)
        #expect(card.frames.count == 10)
        #expect(card.frames.allSatisfy { $0.marks.isEmpty && $0.runningTotal == nil })
    }

    @Test func framesAndRollsAreScoredInIndexOrder() {
        var shuffled = countOnlyGame([[10], [7, 3], [9, 0]] + Array(repeating: [0, 0], count: 7))
        shuffled.frames.reverse()
        shuffled.frames[8].rolls.reverse()
        #expect(Scorer.scorecard(for: shuffled).finalScore == 20 + 19 + 9)
    }
}
