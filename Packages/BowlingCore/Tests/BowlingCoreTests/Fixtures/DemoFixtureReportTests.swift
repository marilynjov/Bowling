import Foundation
import Testing
import BowlingCore
import BowlingFixtures

@Suite struct DemoFixtureReportTests {
    private let games = DemoFixture.games(relativeTo: DemoFixture.referenceDate)

    @Test(arguments: DemoFixtureExpected.reports)
    func reportScopeSelectsTheCompleteGamesOldestFirst(_ report: ExpectedReport) {
        let inScope = games.filter {
            $0.bowlerID == report.bowler.id && $0.isComplete
                && report.eventTypes.contains($0.eventType)
        }
        let ordered = inScope.sorted {
            ($0.sessionDate, $0.gameIndex) < ($1.sessionDate, $1.gameIndex)
        }
        #expect(ordered.map(\.id) == report.games.map(\.id))
        #expect(report.scoreGames == inScope.count)
        #expect(report.rollGames == inScope.filter { $0.entryMode != .finalOnly }.count)
        #expect(report.pinGames == inScope.filter { $0.entryMode == .pinByPin }.count)
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func reportTotalsAddUp(_ report: ExpectedReport) {
        let expected = report.games.map(DemoFixtureExpected.game)
        let scores = expected.map(\.finalScore)
        let rolled = expected.filter { $0.firstBalls != nil }
        func sum(_ value: (ExpectedGame) -> Int?) -> Int { rolled.compactMap(value).reduce(0, +) }

        #expect(report.average == Ratio(scores.reduce(0, +), of: scores.count))
        #expect(report.averageLast10 == Ratio(scores.suffix(10).reduce(0, +), of: min(10, scores.count)))
        #expect(report.averageLast30 == Ratio(scores.suffix(30).reduce(0, +), of: min(30, scores.count)))
        #expect(report.highGame.score == scores.max())
        #expect(DemoFixtureExpected.game(report.highGame.game).finalScore == report.highGame.score)

        #expect(report.firstBalls == sum(\.firstBalls))
        #expect(report.strikes == Ratio(sum(\.strikes), of: sum(\.firstBalls)))
        #expect(report.spares == Ratio(sum(\.spares), of: sum(\.spareAttempts)))
        #expect(report.fouls == Ratio(sum(\.fouls), of: report.rollGames))
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func reportSeriesAndTrendAddUp(_ report: ExpectedReport) {
        let sessions = report.games.reduce(into: [DemoSession]()) { order, game in
            if order.last != game.session { order.append(game.session) }
        }
        func games(in session: DemoSession) -> [Int] {
            report.games.filter { $0.session == session }
                .map { DemoFixtureExpected.game($0).finalScore }
        }

        let bestSeries = Dictionary(grouping: sessions) { games(in: $0).count }
            .mapValues { $0.max { games(in: $0).reduce(0, +) < games(in: $1).reduce(0, +) }! }
        #expect(report.highSeries.map(\.gameCount) == bestSeries.keys.sorted())
        for series in report.highSeries {
            #expect(series.session == bestSeries[series.gameCount])
            #expect(series.total == games(in: series.session).reduce(0, +))
        }

        #expect(report.trend.map(\.session) == sessions)
        var played: [Int] = []
        for point in report.trend {
            let scores = games(in: point.session)
            played += scores
            let lastNine = played.suffix(9)
            #expect(point.sessionAverage == Ratio(scores.reduce(0, +), of: scores.count))
            #expect(point.rollingAverage == Ratio(lastNine.reduce(0, +), of: lastNine.count))
        }
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func reportLeavesAddUp(_ report: ExpectedReport) {
        let expected = report.games.map(DemoFixtureExpected.game)
        let leaves = expected.flatMap(\.leaves)
        let pinAttempts = expected.filter { $0.game.entryMode == .pinByPin }
            .compactMap(\.spareAttempts).reduce(0, +)
        func rate(_ kinds: Set<ExpectedLeaveKind>) -> Ratio {
            let matching = leaves.filter { kinds.contains($0.kind) }
            return Ratio(matching.filter(\.converted).count, of: matching.count)
        }

        #expect(report.splitRate == Ratio(leaves.filter { $0.kind == .split }.count, of: pinAttempts))
        #expect(report.splitConversion == rate([.split]))
        #expect(report.makeableConversion == rate([.makeable, .singlePin]))
        #expect(report.singlePinConversion == rate([.singlePin]))

        let rows = Dictionary(grouping: leaves, by: \.name).mapValues {
            ExpectedLeaveRow(count: $0.count, converted: $0.filter(\.converted).count)
        }
        #expect(report.leaves == rows)

        let byCount = rows.sorted { $0.value.count > $1.value.count }
        #expect(Array(byCount.prefix(report.leavesHead.count).map(\.key)) == report.leavesHead)
        if let next = byCount.dropFirst(report.leavesHead.count).first,
           let last = report.leavesHead.last {
            #expect(rows[last]!.count > next.value.count)
        }

        let misses = rows.mapValues { $0.count - $0.converted }
        let mostMissed = misses.filter { $0.value == misses.values.max() }.map(\.key)
        #expect(mostMissed == [report.leftMostMadeLeast])
    }
}
