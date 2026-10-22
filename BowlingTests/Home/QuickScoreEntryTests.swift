import Testing
@testable import Bowling

@Suite struct QuickScoreEntryTests {
    @Test(arguments: [("0", 0), ("7", 7), ("187", 187), ("300", 300)])
    func acceptsScores(text: String, score: Int) {
        #expect(QuickScoreEntry.score(text) == score)
    }

    @Test(arguments: ["301", "-1", "", "18a", " 7", "300 ", "0300", "1.5", "٣٠٠"])
    func rejectsBadText(text: String) {
        #expect(QuickScoreEntry.score(text) == nil)
    }
}
