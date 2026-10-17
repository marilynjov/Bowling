import Foundation
import Testing
import BowlingCore
import BowlingFixtures

/// Recounts the hand-written 1b expectations with RollWalk, so a slip in
/// DemoFixtureExpected1b.swift fails here and not only against the engine.
@Suite struct DemoFixture1bTotalsTests {
    private let games = DemoFixture.games(relativeTo: DemoFixture.referenceDate)

    private func record(_ demo: DemoGame) throws -> GameRecord {
        try #require(games.first { $0.id == demo.id })
    }

    @Test func everyRollGameInAScopeHasExpectations() {
        let inScopes = Set(DemoFixtureExpected.reports.flatMap(\.games).filter { $0.entryMode != .finalOnly })
        #expect(Set(DemoFixtureExpected.games1b.map(\.game)) == inScopes)
    }

    @Test(arguments: DemoFixtureExpected.games1b)
    func perGameValuesMatchTheRolls(_ expected: ExpectedGame1b) throws {
        let game = try record(expected.game)
        let rolls = RollWalk.rolls(of: game)
        let firstBalls = rolls.filter(\.isFirstBall)
        #expect(firstBalls.count == DemoFixtureExpected.game(expected.game).firstBalls)
        #expect(firstBalls.map { $0.roll.isFoul ? 0 : $0.roll.pinCount }.reduce(0, +) == expected.firstBallPins)

        let framePins = (1...10).map { index in
            rolls.filter { $0.frameIndex == index }.map { $0.roll.isFoul ? 0 : $0.roll.pinCount }.reduce(0, +)
        }
        #expect(framePins == expected.framePins)
        let strikeFrames = firstBalls.filter { $0.roll.pinCount == 10 && $0.roll.rollIndex == 1 }.map(\.frameIndex)
        #expect(Set(strikeFrames) == expected.strikeFrames)
        let open = (1...10).filter { index in
            !rolls.contains { $0.frameIndex == index && $0.standingCountAfter == 0 && !$0.roll.isFoul }
        }
        #expect(open.count == expected.openFrames)

        guard game.entryMode == .pinByPin else {
            #expect(expected.headPin == nil && expected.whatIfScore == nil)
            return
        }
        let thrown = firstBalls.filter { !$0.roll.isFoul }
        #expect(expected.headPin == Ratio(thrown.filter { $0.roll.pinsDown.contains(.pin1) }.count, of: thrown.count))

        let (allMade, rewritten) = singlePinsMade(game)
        #expect(rewritten == expected.missedSinglePins)
        #expect(RollWalk.score(of: allMade) == expected.whatIfScore)
    }

    @Test(arguments: DemoFixtureExpected.reports1b)
    func scopeTotalsAddUp(_ expected: ExpectedReport1b) {
        let scope = expected.scope
        let rolled = scope.games.filter { $0.entryMode != .finalOnly }.map(DemoFixtureExpected.game1b)
        let pinned = rolled.filter { $0.headPin != nil }
        func sum(_ values: [Int]) -> Int { values.reduce(0, +) }

        #expect(expected.openFrames == Ratio(sum(rolled.map(\.openFrames)), of: 10 * scope.rollGames))
        #expect(expected.cleanGames == Ratio(rolled.filter { $0.openFrames == 0 }.count, of: scope.rollGames))
        #expect(expected.firstBallAverage == Ratio(sum(rolled.map(\.firstBallPins)), of: scope.firstBalls))
        #expect(expected.headPin == Ratio(sum(pinned.map { $0.headPin!.numerator }),
                                          of: sum(pinned.map { $0.headPin!.denominator })))
        #expect(expected.byFrame == (1...10).map { index in
            ExpectedFrame1b(strikes: Ratio(rolled.filter { $0.strikeFrames.contains(index) }.count, of: rolled.count),
                            pins: Ratio(sum(rolled.map { $0.framePins[index - 1] }), of: rolled.count))
        })
        let actual = pinned.map { DemoFixtureExpected.game($0.game).finalScore }
        #expect(expected.whatIfActual == Ratio(sum(actual), of: scope.pinGames))
        #expect(expected.whatIfAllMade == Ratio(sum(pinned.map { $0.whatIfScore! }), of: scope.pinGames))
        #expect(expected.whatIfRewritten == sum(pinned.map { $0.missedSinglePins! }))
    }

    /// Every second ball that missed a lone standing pin knocks it down instead; a frame 10
    /// spare made this way gets a fill ball of 0.
    private func singlePinsMade(_ game: GameRecord) -> (GameRecord, Int) {
        let rolls = RollWalk.rolls(of: game)
        var made = game
        var rewritten = 0
        for (first, second) in zip(rolls, rolls.dropFirst())
        where first.isFirstBall && !first.roll.isFoul && !second.isFirstBall
            && second.standingBefore.count == 1 && second.standingCountAfter != 0 {
            let frame = made.frames.firstIndex { $0.frameIndex == second.frameIndex }!
            let roll = made.frames[frame].rolls.firstIndex { $0.rollIndex == second.roll.rollIndex }!
            made.frames[frame].rolls[roll] = RollRecord(
                rollIndex: second.roll.rollIndex, pinsDown: second.standingBefore, pinCount: 1, pinsKnown: true
            )
            if second.frameIndex == 10, made.frames[frame].rolls.count == 2 {
                made.frames[frame].rolls.append(RollRecord(rollIndex: 3, pinCount: 0, pinsKnown: true))
            }
            rewritten += 1
        }
        return (made, rewritten)
    }
}
