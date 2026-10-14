import Foundation
import Testing
import BowlingCore
import BowlingFixtures

@Suite struct DemoFixtureGameTotalsTests {
    private let games = DemoFixture.games(relativeTo: DemoFixture.referenceDate)

    private func record(_ demo: DemoGame) throws -> GameRecord {
        try #require(games.first { $0.id == demo.id })
    }

    @Test func everyGameHasExpectations() {
        #expect(DemoFixtureExpected.games.map(\.game) == DemoGame.allCases)
    }

    @Test(arguments: DemoFixtureExpected.games)
    func perGameTotalsMatch(_ expected: ExpectedGame) throws {
        let game = try record(expected.game)
        #expect(game.finalScore == expected.finalScore)
        guard game.entryMode != .finalOnly else {
            #expect(expected.firstBalls == nil)
            return
        }
        #expect(RollWalk.score(of: game) == expected.finalScore)

        let rolls = RollWalk.rolls(of: game)
        let firstBalls = rolls.filter(\.isFirstBall)
        #expect(firstBalls.count == expected.firstBalls)
        #expect(firstBalls.filter { $0.roll.pinCount == 10 }.count == expected.strikes)
        #expect(rolls.filter(\.roll.isFoul).count == expected.fouls)

        let attempts = zip(rolls, rolls.dropFirst()).filter { first, second in
            first.isFirstBall && !second.isFirstBall && second.frameIndex == first.frameIndex
        }
        #expect(attempts.count == expected.spareAttempts)
        #expect(attempts.filter { $1.standingCountAfter == 0 }.count == expected.spares)

        let leaves = attempts.filter { game.entryMode == .pinByPin && !$0.0.roll.isFoul }
            .map { first, second in
                let left = first.standingBefore.subtracting(first.roll.pinsDown)
                let name = left.pins.map(String.init).joined(separator: "-")
                return "\(name) \(second.standingCountAfter == 0 ? "made" : "missed")"
            }
        let expectedLeaves = expected.leaves.map { "\($0.name) \($0.converted ? "made" : "missed")" }
        #expect(leaves == expectedLeaves)
    }

    @Test func leaveKindsAreConsistentAcrossGames() {
        let all = DemoFixtureExpected.games.flatMap(\.leaves)
        for (name, leaves) in Dictionary(grouping: all, by: \.name) {
            #expect(Set(leaves.map(\.kind)).count == 1, "\(name)")
            #expect(Set(leaves.map(\.isWashout)).count == 1, "\(name)")
            #expect((leaves[0].kind == .singlePin) == !name.contains("-"), "\(name)")
        }
    }
}

extension DemoGame {
    var entryMode: EntryMode {
        DemoFixture.games(relativeTo: DemoFixture.referenceDate).first { $0.id == id }!.entryMode
    }
}
