import Foundation
import Testing
import BowlingCore
import BowlingFixtures

/// StatsEngine's 1b fields against the hand-computed values in DemoFixtureExpected1b.swift.
@Suite struct StatsEngine1bTests {
    private static let now = DemoFixture.referenceDate
    private static let games = DemoFixture.games(relativeTo: now)

    /// What the repository would pass, incomplete games included, reversed so the engine
    /// cannot rely on input order.
    private func report(_ expected: ExpectedReport1b) -> StatsReport {
        let scope = expected.scope
        let filter = StatsFilter(datePreset: .allTime, eventTypes: scope.eventTypes, bowlerID: scope.bowler.id)
        let scoped = Self.games.filter {
            $0.bowlerID == scope.bowler.id && scope.eventTypes.contains($0.eventType)
        }
        return StatsEngine.report(games: scoped.reversed(), filter: filter)
    }

    /// One game on its own, so a miscount points at the game.
    private func report(_ expected: ExpectedGame1b) -> StatsReport {
        let game = Self.games.first { $0.id == expected.game.id }!
        let filter = StatsFilter(datePreset: .allTime, eventTypes: Set(EventType.allCases),
                                 bowlerID: expected.game.bowler.id)
        return StatsEngine.report(games: [game], filter: filter)
    }

    private func rate(_ ratio: Ratio) -> Rate { Rate(hits: ratio.numerator, attempts: ratio.denominator) }
    private func mean(_ ratio: Ratio) -> Mean { Mean(total: ratio.numerator, count: ratio.denominator) }

    @Test(arguments: DemoFixtureExpected.reports1b)
    func openAndCleanGames(_ expected: ExpectedReport1b) {
        let report = report(expected)
        #expect(report.openFrames == rate(expected.openFrames))
        #expect(report.cleanGames == rate(expected.cleanGames))
    }

    @Test(arguments: DemoFixtureExpected.reports1b)
    func firstBalls(_ expected: ExpectedReport1b) {
        let report = report(expected)
        #expect(report.firstBallAverage == mean(expected.firstBallAverage))
        #expect(report.headPin == rate(expected.headPin))
    }

    @Test(arguments: DemoFixtureExpected.reports1b)
    func byFrame(_ expected: ExpectedReport1b) {
        let rows = expected.byFrame.enumerated().map { offset, frame in
            FrameStats(frameIndex: offset + 1, strikes: rate(frame.strikes), pins: mean(frame.pins))
        }
        #expect(report(expected).byFrame == rows)
    }

    @Test(arguments: DemoFixtureExpected.reports1b)
    func whatIfSinglePins(_ expected: ExpectedReport1b) {
        let whatIf = report(expected).whatIfSinglePins
        #expect(whatIf == WhatIfSinglePins(actual: mean(expected.whatIfActual),
                                           allMade: mean(expected.whatIfAllMade),
                                           rewritten: expected.whatIfRewritten))
        let gain = Double(expected.whatIfAllMade.numerator - expected.whatIfActual.numerator)
            / Double(expected.whatIfActual.denominator)
        #expect(whatIf.difference == gain)
    }

    @Test(arguments: DemoFixtureExpected.games1b)
    func perGame(_ expected: ExpectedGame1b) {
        let report = report(expected)
        let firstBalls = DemoFixtureExpected.game(expected.game).firstBalls!
        #expect(report.openFrames == Rate(hits: expected.openFrames, attempts: 10))
        #expect(report.cleanGames == Rate(hits: expected.openFrames == 0 ? 1 : 0, attempts: 1))
        #expect(report.firstBallAverage == Mean(total: expected.firstBallPins, count: firstBalls))
        #expect(report.byFrame.map(\.pins.total) == expected.framePins)
        #expect(Set(report.byFrame.filter { $0.strikes.hits == 1 }.map(\.frameIndex)) == expected.strikeFrames)
        if let headPin = expected.headPin, let score = expected.whatIfScore {
            let actual = DemoFixtureExpected.game(expected.game).finalScore
            #expect(report.headPin == rate(headPin))
            #expect(report.whatIfSinglePins == WhatIfSinglePins(
                actual: Mean(total: actual, count: 1), allMade: Mean(total: score, count: 1),
                rewritten: expected.missedSinglePins!))
        }
    }

    // §6 applicability: head pin and the what-if read pins, so countOnly games add nothing.
    @Test(arguments: DemoFixtureExpected.games1b.filter { $0.headPin == nil })
    func countOnlyGamesHaveNoPinStats(_ expected: ExpectedGame1b) {
        let report = report(expected)
        #expect(report.headPin == Rate(hits: 0, attempts: 0))
        #expect(report.whatIfSinglePins == WhatIfSinglePins(
            actual: Mean(total: 0, count: 0), allMade: Mean(total: 0, count: 0), rewritten: 0))
        #expect(report.whatIfSinglePins.difference == nil)
    }

    // §6 applicability: a finalOnly game has no frames.
    @Test func finalOnlyGamesHaveNoFrameStats() {
        let game = Self.games.first { $0.id == DemoGame.tournament3.id }!
        let filter = StatsFilter(datePreset: .allTime, eventTypes: [.tournament], bowlerID: DemoBowler.owner.id)
        let report = StatsEngine.report(games: [game], filter: filter)
        #expect(report.openFrames == Rate(hits: 0, attempts: 0))
        #expect(report.cleanGames == Rate(hits: 0, attempts: 0))
        #expect(report.firstBallAverage == Mean(total: 0, count: 0))
        #expect(report.byFrame.map(\.frameIndex) == Array(1...10))
        #expect(report.byFrame.allSatisfy { $0.strikes.attempts == 0 && $0.pins.count == 0 })
    }

    @Test func incompleteGamesAreIgnored() {
        let game = Self.games.first { $0.id == DemoGame.practiceInProgress.id }!
        let filter = StatsFilter(datePreset: .allTime, eventTypes: [.practice], bowlerID: DemoBowler.owner.id)
        let report = StatsEngine.report(games: [game], filter: filter)
        #expect(report.openFrames == Rate(hits: 0, attempts: 0))
        #expect(report.headPin == Rate(hits: 0, attempts: 0))
        #expect(report.whatIfSinglePins.allMade == Mean(total: 0, count: 0))
    }

    // In frame 10 a ball after a strike that leaves one pin, then a miss ("X 10 -"), is a
    // spare attempt and is rewritten without an extra ball. Real: F1-F7 30 each = 210
    // | F8 10+10+10 = 30, 240 | F9 10+10+9 = 29, 269 | F10 10+9+0 = 19, 288.
    // Made: F10 10+9+1 = 20, so 289; F9's bonus stops at roll 2 and is unchanged.
    @Test func frameTenSpareAttemptAfterAStrikeIsRewrittenInPlace() {
        let strike = RollRecord(rollIndex: 1, pinsDown: .all, pinCount: 10, pinsKnown: true)
        let leftTen = PinSet.all.subtracting(.pin10)
        let frames = (1...9).map { FrameRecord(frameIndex: $0, rolls: [strike]) } + [
            FrameRecord(frameIndex: 10, rolls: [
                strike,
                RollRecord(rollIndex: 2, pinsDown: leftTen, pinCount: 9, pinsKnown: true),
                RollRecord(rollIndex: 3, pinsDown: [], pinCount: 0, pinsKnown: true),
            ]),
        ]
        let game = GameRecord(gameIndex: 1, entryMode: .pinByPin, finalScore: 288, isComplete: true,
                              frames: frames, sessionDate: Self.now, eventType: .practice)
        let filter = StatsFilter(datePreset: .allTime, eventTypes: [.practice], bowlerID: DemoBowler.owner.id)
        let whatIf = StatsEngine.report(games: [game], filter: filter).whatIfSinglePins
        #expect(whatIf == WhatIfSinglePins(actual: Mean(total: 288, count: 1),
                                           allMade: Mean(total: 289, count: 1), rewritten: 1))
    }
}
