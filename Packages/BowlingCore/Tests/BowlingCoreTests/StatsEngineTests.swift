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

    private func rate(_ ratio: Ratio) -> Rate {
        Rate(hits: ratio.numerator, attempts: ratio.denominator)
    }

    /// One complete game on its own, so a miscount points at the game.
    private func report(_ expected: ExpectedGame) -> StatsReport {
        var game = Self.games.first { $0.id == expected.game.id }!
        game.isComplete = true
        let filter = StatsFilter(datePreset: .allTime, eventTypes: Set(EventType.allCases),
                                 bowlerID: expected.game.bowler.id)
        return StatsEngine.report(games: [game], filter: filter)
    }

    @Test(arguments: DemoFixtureExpected.games.filter { $0.firstBalls != nil })
    func rollCountsPerGame(_ expected: ExpectedGame) {
        let report = report(expected)
        #expect(report.firstBalls == expected.firstBalls)
        #expect(report.strikes == Rate(hits: expected.strikes!, attempts: expected.firstBalls!))
        #expect(report.spares == Rate(hits: expected.spares!, attempts: expected.spareAttempts!))
        #expect(report.fouls == Mean(total: expected.fouls!, count: 1))
    }

    // §6 applicability: a finalOnly game has no rolls, so it adds nothing to roll stats.
    @Test(arguments: DemoFixtureExpected.games.filter { $0.firstBalls == nil })
    func finalOnlyGamesHaveNoRollStats(_ expected: ExpectedGame) {
        let report = report(expected)
        #expect(report.scoreGames == 1)
        #expect(report.firstBalls == 0)
        #expect(report.strikes == Rate(hits: 0, attempts: 0))
        #expect(report.spares == Rate(hits: 0, attempts: 0))
        #expect(report.fouls == Mean(total: 0, count: 0))
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func strikesAndSpares(_ expected: ExpectedReport) {
        let report = report(expected)
        #expect(report.firstBalls == expected.firstBalls)
        #expect(report.strikes == rate(expected.strikes))
        #expect(report.spares == rate(expected.spares))
        #expect(report.fouls == mean(expected.fouls))
    }

    @Test(arguments: DemoFixtureExpected.games.filter { $0.game.entryMode == .pinByPin })
    func leavesPerGame(_ expected: ExpectedGame) {
        let rows = report(expected).leaves
        let byName = Dictionary(grouping: expected.leaves, by: \.name)
        #expect(Set(rows.map(\.leave.name)) == Set(byName.keys))
        for row in rows {
            let leaves = byName[row.leave.name] ?? []
            #expect(row.conversion == Rate(hits: leaves.filter(\.converted).count, attempts: leaves.count))
            #expect(row.leave.isWashout == leaves.first?.isWashout)
            #expect(ExpectedLeaveKind(row.leave.kind) == leaves.first?.kind)
        }
    }

    // §6 applicability: countOnly games have no pins, so no leaves.
    @Test(arguments: DemoFixtureExpected.games.filter { $0.game.entryMode == .countOnly })
    func countOnlyGamesHaveNoLeaves(_ expected: ExpectedGame) {
        let report = report(expected)
        #expect(report.pinGames == 0)
        #expect(report.leaves.isEmpty)
        #expect(report.leftMostMadeLeast == nil)
        #expect(report.splitRate == Rate(hits: 0, attempts: 0))
        #expect(report.makeableConversion == Rate(hits: 0, attempts: 0))
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func leaveRates(_ expected: ExpectedReport) {
        let report = report(expected)
        #expect(report.splitRate == rate(expected.splitRate))
        #expect(report.splitConversion == rate(expected.splitConversion))
        #expect(report.makeableConversion == rate(expected.makeableConversion))
        #expect(report.singlePinConversion == rate(expected.singlePinConversion))
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func leavesTable(_ expected: ExpectedReport) {
        let rows = report(expected).leaves
        let table = Dictionary(uniqueKeysWithValues: rows.map {
            ($0.leave.name, ExpectedLeaveRow(count: $0.conversion.attempts, converted: $0.conversion.hits))
        })
        #expect(table == expected.leaves)
        #expect(Array(rows.prefix(expected.leavesHead.count).map(\.leave.name)) == expected.leavesHead)
    }

    // Contract OQ-17: by count descending, equal counts by pin numbers ascending.
    @Test(arguments: DemoFixtureExpected.reports)
    func leavesAreSortedByCountThenPins(_ expected: ExpectedReport) {
        let rows = report(expected).leaves
        for (a, b) in zip(rows, rows.dropFirst()) {
            let countA = a.conversion.attempts, countB = b.conversion.attempts
            #expect(countA > countB || (countA == countB && a.leave.pins.pins.lexicographicallyPrecedes(b.leave.pins.pins)))
        }
    }

    @Test(arguments: DemoFixtureExpected.reports)
    func leftMostMadeLeast(_ expected: ExpectedReport) {
        let report = report(expected)
        #expect(report.leftMostMadeLeast?.leave.name == expected.leftMostMadeLeast)
        #expect(report.leftMostMadeLeast.map { report.leaves.contains($0) } == true)
    }

    // Nine strikes, then a 10 pin left and made in frame 10, then a strike: 289.
    @Test func noCalloutWhenEveryLeaveWasConverted() {
        let strike = RollRecord(rollIndex: 1, pinsDown: .all, pinCount: 10, pinsKnown: true)
        let leftTen = PinSet.all.subtracting(.pin10)
        let tenth = FrameRecord(frameIndex: 10, rolls: [
            RollRecord(rollIndex: 1, pinsDown: leftTen, pinCount: 9, pinsKnown: true),
            RollRecord(rollIndex: 2, pinsDown: .pin10, pinCount: 1, pinsKnown: true),
            RollRecord(rollIndex: 3, pinsDown: .all, pinCount: 10, pinsKnown: true),
        ])
        let game = GameRecord(gameIndex: 1, entryMode: .pinByPin, finalScore: 289, isComplete: true,
                              frames: (1...9).map { FrameRecord(frameIndex: $0, rolls: [strike]) } + [tenth],
                              sessionDate: Self.now, eventType: .practice)
        let filter = StatsFilter(datePreset: .allTime, eventTypes: [.practice], bowlerID: DemoBowler.owner.id)
        let report = StatsEngine.report(games: [game], filter: filter)
        #expect(report.leaves.map(\.leave.name) == ["10"])
        #expect(report.leftMostMadeLeast == nil)
    }

    // Contract OQ-4: rolls from an entry mode this version does not know are not trusted,
    // but the typed final score still counts.
    @Test func unknownEntryModeCountsOnlyTowardScores() {
        var game = Self.games.first { $0.id == DemoGame.leagueNight1.id }!
        game.entryMode = .unknown
        let filter = StatsFilter(datePreset: .allTime, eventTypes: [.league], bowlerID: DemoBowler.owner.id)
        let report = StatsEngine.report(games: [game], filter: filter)
        #expect(report.average == Mean(total: 162, count: 1))
        #expect(report.rollGames == 0)
        #expect(report.firstBalls == 0)
        #expect(report.leaves.isEmpty)
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

extension ExpectedLeaveKind {
    init?(_ kind: LeaveKind) {
        switch kind {
        case .singlePin: self = .singlePin
        case .makeable: self = .makeable
        case .split: self = .split
        case .strike: return nil
        }
    }
}
