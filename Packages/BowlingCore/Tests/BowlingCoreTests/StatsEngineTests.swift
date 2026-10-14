import Foundation
import Testing
import BowlingCore
import BowlingFixtures

/// StatsEngine against the hand-computed values in DemoFixtureExpectedReports.swift.
@Suite struct StatsEngineTests {
    private static let now = DemoFixture.referenceDate
    private static let games = DemoFixture.games(relativeTo: now)

    /// What the repository would pass: the bowler's games in the scope's event types,
    /// incomplete ones included, in reverse so the engine cannot rely on input order.
    private func report(_ expected: ExpectedReport) -> StatsReport {
        let filter = StatsFilter(datePreset: .allTime, eventTypes: expected.eventTypes,
                                 bowlerID: expected.bowler.id)
        let scoped = Self.games.filter {
            $0.bowlerID == expected.bowler.id && expected.eventTypes.contains($0.eventType)
        }
        return StatsEngine.report(games: scoped.reversed(), filter: filter)
    }

    private func date(_ session: DemoSession) -> Date {
        Self.games.first { $0.sessionID == session.id }!.sessionDate
    }

    private func mean(_ ratio: Ratio) -> Mean {
        Mean(total: ratio.numerator, count: ratio.denominator)
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func sampleSizes(_ expected: ExpectedReport) {
        let report = report(expected)
        #expect(report.scoreGames == expected.scoreGames)
        #expect(report.rollGames == expected.rollGames)
        #expect(report.pinGames == expected.pinGames)
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func averages(_ expected: ExpectedReport) {
        let report = report(expected)
        #expect(report.average == mean(expected.average))
        #expect(report.averageLast10 == mean(expected.averageLast10))
        #expect(report.averageLast30 == mean(expected.averageLast30))
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func highGame(_ expected: ExpectedReport) {
        let game = expected.highGame.game
        let ref = GameRef(gameID: game.id, sessionID: game.session.id, date: date(game.session))
        #expect(report(expected).highGame == HighGame(score: expected.highGame.score, game: ref))
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func highSeries(_ expected: ExpectedReport) {
        let series = expected.highSeries.map {
            HighSeries(gameCount: $0.gameCount, total: $0.total,
                       sessionID: $0.session.id, date: date($0.session))
        }
        #expect(report(expected).highSeries == series)
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func trend(_ expected: ExpectedReport) {
        let trend = expected.trend.map {
            TrendPoint(sessionID: $0.session.id, date: date($0.session),
                       sessionAverage: mean($0.sessionAverage),
                       rollingAverage: mean($0.rollingAverage))
        }
        #expect(report(expected).trend == trend)
    }

    @Test func reportCarriesItsFilter() {
        let filter = StatsFilter(datePreset: .thisMonth, eventTypes: [.league], bowlerID: DemoBowler.owner.id)
        #expect(StatsEngine.report(games: [], filter: filter).filter == filter)
    }

    // §6: a game paused at frame 5 never pulls the average down.
    @Test func incompleteGamesAreIgnored() {
        let paused = Self.games.filter { $0.id == DemoGame.practiceInProgress.id }
        let filter = StatsFilter(datePreset: .allTime, eventTypes: [.practice], bowlerID: DemoBowler.owner.id)
        let report = StatsEngine.report(games: paused, filter: filter)
        #expect(report.scoreGames == 0)
        #expect(report.average == Mean(total: 0, count: 0))
        #expect(report.highGame == nil)
        #expect(report.highSeries.isEmpty)
        #expect(report.trend.isEmpty)
    }
}
