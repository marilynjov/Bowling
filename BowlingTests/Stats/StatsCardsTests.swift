import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct StatsCardsTests {
    let bowler = BowlerID()
    let later: [StatsCardID] = [.byFrameStrike, .byFrameAverage, .whatIfSinglePins]

    func finalOnly(_ scores: [Int]) -> [GameRecord] {
        let session = SessionID()
        return scores.enumerated().map { index, score in
            GameRecord(
                bowlerID: bowler, gameIndex: index + 1, entryMode: .finalOnly, finalScore: score,
                isComplete: true, sessionID: session, sessionDate: .now, eventType: .league
            )
        }
    }

    func report(_ games: [GameRecord]) -> StatsReport {
        StatsEngine.report(games: games, filter: StatsFilter(bowlerID: bowler))
    }

    func card(_ id: StatsCardID, _ report: StatsReport) throws -> StatsCard {
        try #require(StatsCards.make(cards: [id], report: report).first)
    }

    @Test(arguments: [StatsProfile.casual, .league, .competitive])
    func everyPresetCardRendersForEachStyle(_ profile: StatsProfile) {
        let preset = StatsPreset.statsCards(for: profile)
        let cards = StatsCards.make(cards: preset, report: PreviewData.report)
        #expect(cards.map(\.id) == preset)
        for card in cards where !later.contains(card.id) {
            switch card.body {
            case .notApplicable, .comingSoon: Issue.record("\(card.id) does not render: \(card.body)")
            default: break
            }
        }
    }

    @Test func emptyReportExplainsEveryCard() throws {
        let ids = StatsCardID.allCases.filter { !later.contains($0) }
        let cards = StatsCards.make(cards: ids, report: report([]))
        #expect(cards.map(\.id) == ids)
        for card in cards {
            guard case .notApplicable = card.body else {
                Issue.record("\(card.id) is \(card.body)")
                continue
            }
        }
        #expect(try card(.average, report([])).body == .notApplicable("No complete games yet."))
        #expect(try card(.strikePct, report([])).body == .notApplicable("Enter frames to see strikes and spares."))
        #expect(try card(.leavesTable, report([])).body == .notApplicable("Enter pins to see leaves."))
        #expect(cards.map(\.title) == [
            "Average", "High game", "High series", "Trend", "Strike %", "Spare %", "Fouls", "Open %",
            "Clean games %", "First-ball average", "Head pin %", "Leaves", "Left most, made least",
            "Split conversion %", "Makeable conversion %", "Single-pin conversion %",
        ])
    }

    @Test func finalOnlyGamesShowOverviewOnly() throws {
        let report = report(finalOnly([200, 180]))
        guard case .tile(let tile, _) = try card(.average, report).body else {
            Issue.record("average is not a tile")
            return
        }
        #expect(tile.value == "190")
        #expect(try card(.strikePct, report).body == .notApplicable("Enter frames to see strikes and spares."))
        #expect(try card(.leavesTable, report).body == .notApplicable("Enter pins to see leaves."))
    }

    @Test func laterCardsAreComingSoon() {
        let cards = StatsCards.make(cards: later, report: PreviewData.report)
        #expect(cards.map(\.body) == [.comingSoon, .comingSoon, .comingSoon])
        #expect(cards.map(\.title) == ["Strikes by frame", "Average by frame", "What if"])
    }

    @Test func averageFootnoteNeedsMoreThanTenGames() throws {
        guard case .tile(_, let ten) = try card(.average, report(finalOnly(Array(repeating: 200, count: 10)))).body,
              case .tile(_, let eleven) = try card(.average, report(finalOnly(Array(repeating: 200, count: 11)))).body
        else {
            Issue.record("average is not a tile")
            return
        }
        #expect(ten == nil)
        #expect(eleven == "Last 10 200")
    }

    @Test func highGameSampleIsItsDate() throws {
        let report = PreviewData.report
        let high = try #require(report.highGame)
        guard case .tile(let tile, _) = try card(.highGame, report).body else {
            Issue.record("high game is not a tile")
            return
        }
        #expect(tile.value == "\(high.score)")
        #expect(tile.sample == high.game.date.formatted(.dateTime.month(.abbreviated).day()))
    }

    @Test func leftMostNilHasNoLeave() throws {
        var report = PreviewData.report
        report.leftMostMadeLeast = nil
        #expect(try card(.leftMostMadeLeast, report).body == .leftMost(nil))
    }

    @Test func leaveRowText() throws {
        var report = PreviewData.report
        report.leaves = [LeaveRow(leave: PreviewData.leave(7, 10), conversion: Rate(hits: 7, attempts: 9))]
        guard case .leaves(let rows) = try card(.leavesTable, report).body else {
            Issue.record("leaves is not a list")
            return
        }
        #expect(rows.map(\.made) == ["Made 7 of 9"])
        #expect(rows.map(\.rate) == [StatFormat.percent(Rate(hits: 7, attempts: 9))])
        #expect(rows.map(\.accessibilityLabel) == ["Leave 7, 10, split, made 7 of 9"])
    }

    @Test func trendCountsSessions() throws {
        guard case .trend(let trend) = try card(.trendChart, PreviewData.report).body else {
            Issue.record("trend is not a chart")
            return
        }
        let points = PreviewData.report.trend.filter { $0.sessionAverage.count > 0 }
        #expect(trend.points == points)
        #expect(trend.sample == (points.count == 1 ? "1 session" : "\(points.count) sessions"))
    }
}
