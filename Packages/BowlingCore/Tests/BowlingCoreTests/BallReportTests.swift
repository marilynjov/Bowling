import BowlingCore
import BowlingFixtures
import Foundation
import Testing

/// §6 "Ball report" against MixedBallFixture (§9 Phase 1b). Expected values and their
/// arithmetic are in MixedBallExpected.swift.
@Suite struct BallReportTests {
    let games = MixedBallFixture.games(relativeTo: MixedBallExpected.now)

    var strikeBallMaintenance: BallMaintenance {
        BallMaintenance(
            ball: DemoBall.ownerStrike.id, games: games,
            events: MixedBallFixture.strikeBallMaintenance(relativeTo: MixedBallExpected.now),
            resurfaceIntervalGames: MixedBallFixture.strikeBallResurfaceInterval
        )
    }

    func report(_ expected: MixedBallExpected.Report) -> BallReport {
        let maintenance = expected.ball == .ownerStrike
            ? strikeBallMaintenance
            : BallMaintenance(ball: expected.ball.id, games: games, events: [], resurfaceIntervalGames: nil)
        return StatsEngine.ballReport(for: expected.ball.id, games: games, maintenance: maintenance)
    }

    @Test(arguments: MixedBallFixture.games(relativeTo: MixedBallExpected.now))
    func fixtureGamesAreValidAndTheirScoresMatch(_ game: GameRecord) {
        #expect(Scorer.validate(game).isEmpty)
        guard game.entryMode != .finalOnly, game.isComplete else { return }
        #expect(Scorer.scorecard(for: game).finalScore == game.finalScore)
    }

    @Test(arguments: [MixedBallExpected.strikeBall, MixedBallExpected.spareBall])
    func usage(_ expected: MixedBallExpected.Report) {
        let report = report(expected)
        #expect(report.ballID == expected.ball.id)
        #expect(report.gamesBowled == expected.gamesBowled)
        #expect(report.firstBalls == expected.firstBalls)
        #expect(report.spareAttempts == expected.spareAttempts)
        #expect(report.firstUsed == MixedBallExpected.date(expected.firstUsed))
        #expect(report.lastUsed == MixedBallExpected.date(expected.lastUsed))
    }

    @Test(arguments: [MixedBallExpected.strikeBall, MixedBallExpected.spareBall])
    func asAStrikeBallCountsOnlyFirstBallsThrownWithIt(_ expected: MixedBallExpected.Report) {
        let report = report(expected)
        #expect(report.strikes == Rate(expected.strikes))
        #expect(report.firstBallAverage == Mean(expected.firstBallAverage))
        #expect(report.headPin == Rate(expected.headPin))
        #expect(report.averageAsMainBall == Mean(expected.averageAsMainBall))
    }

    @Test(arguments: [MixedBallExpected.strikeBall, MixedBallExpected.spareBall])
    func asASpareBallCountsOnlySpareAttemptsThrownWithIt(_ expected: MixedBallExpected.Report) {
        let report = report(expected)
        #expect(report.spares == Rate(expected.spares))
        #expect(report.singlePinConversion == Rate(expected.singlePinConversion))
        #expect(report.splitConversion == Rate(expected.splitConversion))
        #expect(report.leaves.map(\.leave.name) == expected.leaves.map(\.name))
        #expect(report.leaves.map(\.conversion) == expected.leaves.map { Rate(hits: $0.made, attempts: $0.count) })
    }

    @Test(arguments: [MixedBallExpected.strikeBall, MixedBallExpected.spareBall])
    func groupsUnderTenFirstBallsFoldIntoOther(_ expected: MixedBallExpected.Report) {
        let report = report(expected)
        func rows(_ conditions: [MixedBallExpected.Condition]) -> [ConditionRow] {
            conditions.map { ConditionRow(id: $0.id, strikes: Rate($0.strikes), firstBallAverage: Mean($0.firstBallPins)) }
        }
        #expect(report.byOilPattern == rows(expected.byOilPattern))
        #expect(report.byCenter == rows(expected.byCenter))
    }

    @Test func aGroupNeedsAtLeastTenFirstBallsToBeShown() {
        let ball = BallID()
        let otherBall = BallID()
        let tenCenter = UUID()
        let nineCenter = UUID()
        /// A complete countOnly game of ten 7-2 frames (90); `ball` throws the first balls of
        /// frames 1 through `ballFrames`, `otherBall` everything else.
        func game(at center: UUID, ballFrames: Int) -> GameRecord {
            let frames = (1...10).map { index in
                FrameRecord(frameIndex: index, rolls: [
                    RollRecord(rollIndex: 1, pinCount: 7, pinsKnown: false, ballID: index <= ballFrames ? ball : otherBall),
                    RollRecord(rollIndex: 2, pinCount: 2, pinsKnown: false, ballID: otherBall),
                ])
            }
            return GameRecord(
                gameIndex: 1, entryMode: .countOnly, defaultBallID: otherBall, finalScore: 90,
                isComplete: true, frames: frames, sessionID: SessionID(), sessionDate: MixedBallExpected.now,
                eventType: .practice, centerID: center
            )
        }
        let games = [game(at: tenCenter, ballFrames: 10), game(at: nineCenter, ballFrames: 9)]
        let report = StatsEngine.ballReport(
            for: ball, games: games,
            maintenance: BallMaintenance(ball: ball, games: games, events: [], resurfaceIntervalGames: nil)
        )
        // 10 first balls at tenCenter: shown, 0 strikes, 10 × 7 = 70 pins.
        // 9 at nineCenter: 9 < 10, so Other, 0 strikes, 9 × 7 = 63 pins.
        #expect(report.byCenter == [
            ConditionRow(id: tenCenter, strikes: Rate(hits: 0, attempts: 10), firstBallAverage: Mean(total: 70, count: 10)),
            ConditionRow(id: nil, strikes: Rate(hits: 0, attempts: 9), firstBallAverage: Mean(total: 63, count: 9)),
        ])
    }

    @Test(arguments: [MixedBallExpected.strikeBall, MixedBallExpected.spareBall])
    func overTimeIsStrikeRatePerSession(_ expected: MixedBallExpected.Report) {
        let points = expected.overTime.map {
            BallTrendPoint(sessionID: $0.session.id, date: MixedBallExpected.date($0.session), strikes: Rate($0.strikes))
        }
        #expect(report(expected).overTime == points)
    }

    @Test func gamesSinceResurfaceCountsOnlyGamesAfterTheLatestResurface() {
        let report = report(MixedBallExpected.strikeBall)
        #expect(report.maintenance.gamesBowled == MixedBallExpected.strikeBallGamesBowled)
        #expect(report.maintenance.gamesSinceResurface == MixedBallExpected.strikeBallGamesSinceResurface)
        #expect(report.maintenance.isResurfaceDue)
        // Maintenance markers for the over-time chart, newest first.
        #expect(report.maintenance.events.map(\.kind) == [.polish, .resurface])
    }

    @Test func aBallWithNoGamesHasEmptySamples() {
        let ball = BallID()
        let report = StatsEngine.ballReport(
            for: ball, games: games,
            maintenance: BallMaintenance(ball: ball, games: games, events: [], resurfaceIntervalGames: nil)
        )
        #expect(report.gamesBowled == 0)
        #expect(report.firstUsed == nil)
        #expect(report.strikes == Rate(hits: 0, attempts: 0))
        #expect(report.averageAsMainBall == Mean(total: 0, count: 0))
        #expect(report.leaves.isEmpty)
        #expect(report.byOilPattern.isEmpty)
        #expect(report.byCenter.isEmpty)
        #expect(report.overTime.isEmpty)
    }

    @Test func compareBallsReturnsOneRowPerBallInOrder() {
        let rows = StatsEngine.compareBalls([DemoBall.ownerSpare.id, DemoBall.ownerStrike.id], games: games)
        let expected = [MixedBallExpected.spareBall, MixedBallExpected.strikeBall].map {
            BallComparisonRow(
                ballID: $0.ball.id, gamesBowled: $0.gamesBowled,
                averageAsMainBall: Mean($0.averageAsMainBall), strikes: Rate($0.strikes),
                firstBallAverage: Mean($0.firstBallAverage), spares: Rate($0.spares)
            )
        }
        #expect(rows == expected)
    }
}

extension Rate {
    init(_ ratio: Ratio) {
        self.init(hits: ratio.numerator, attempts: ratio.denominator)
    }
}

extension Mean {
    init(_ ratio: Ratio) {
        self.init(total: ratio.numerator, count: ratio.denominator)
    }
}
