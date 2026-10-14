import Testing
import BowlingCore

/// §4 "Marks for display".
@Suite struct ScorerMarkTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let frames: [[Int]]
        let marks: [[Mark]]
        var testDescription: String { name }
    }

    static let cases: [Case] = [
        Case(name: "strike", frames: [[10]], marks: [[.strike]]),
        Case(name: "spare", frames: [[7, 3]], marks: [[.count(7), .spare]]),
        Case(name: "gutter then spare", frames: [[0, 10]], marks: [[.gutter, .spare]]),
        Case(name: "open with miss", frames: [[9, 0]], marks: [[.count(9), .gutter]]),
        Case(name: "double gutter", frames: [[0, 0]], marks: [[.gutter, .gutter]]),
        Case(name: "first ball only", frames: [[4]], marks: [[.count(4)]]),
        Case(name: "tenth X X X", frames: Array(repeating: [0, 0], count: 9) + [[10, 10, 10]],
             marks: Array(repeating: [.gutter, .gutter], count: 9) + [[.strike, .strike, .strike]]),
        Case(name: "tenth X 7 /", frames: Array(repeating: [0, 0], count: 9) + [[10, 7, 3]],
             marks: Array(repeating: [.gutter, .gutter], count: 9) + [[.strike, .count(7), .spare]]),
        Case(name: "tenth X 0 0", frames: Array(repeating: [0, 0], count: 9) + [[10, 0, 0]],
             marks: Array(repeating: [.gutter, .gutter], count: 9) + [[.strike, .gutter, .gutter]]),
        Case(name: "tenth 8 / X", frames: Array(repeating: [0, 0], count: 9) + [[8, 2, 10]],
             marks: Array(repeating: [.gutter, .gutter], count: 9) + [[.count(8), .spare, .strike]]),
        Case(name: "tenth X X 9", frames: Array(repeating: [0, 0], count: 9) + [[10, 10, 9]],
             marks: Array(repeating: [.gutter, .gutter], count: 9) + [[.strike, .strike, .count(9)]]),
    ]

    @Test(arguments: cases)
    func marks(_ c: Case) {
        let card = Scorer.scorecard(for: countOnlyGame(c.frames))
        let expected = c.marks + Array(repeating: [], count: 10 - c.marks.count)
        #expect(card.frames.map(\.marks) == expected)
    }
}
