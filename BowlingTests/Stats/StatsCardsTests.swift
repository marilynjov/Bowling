import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct StatsCardsTests {
    let bowler = BowlerID()

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
        try #require(StatsCards.make(cards: [id], report: report, locale: Locale(identifier: "en_US")).first)
    }

    @Test(arguments: [StatsProfile.casual, .league, .competitive])
    func everyPresetCardRendersForEachStyle(_ profile: StatsProfile) {
        let preset = StatsPreset.statsCards(for: profile)
        let cards = StatsCards.make(cards: preset, report: PreviewData.report)
        #expect(cards.map(\.id) == preset)
        for card in cards {
            switch card.body {
            case .notApplicable: Issue.record("\(card.id) does not render: \(card.body)")
            default: break
            }
        }
    }

    @Test func emptyReportExplainsEveryCard() throws {
        let ids = StatsCardID.allCases
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
            "Strikes by frame", "Average by frame", "What if",
        ])
        #expect(try card(.byFrameAverage, report([])).body == .notApplicable("Enter frames to see strikes and spares."))
        #expect(try card(.whatIfSinglePins, report([])).body == .notApplicable("Enter pins to see leaves."))
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

    @Test func everyCardRendersFromTheDemoFixture() {
        for card in StatsCards.make(cards: StatsCardID.allCases, report: PreviewData.report) {
            switch card.body {
            case .notApplicable: Issue.record("\(card.id) does not render: \(card.body)")
            default: break
            }
        }
    }

    /// Four games with frames entered: frame 1 struck once and averaged 7.5 pins, the rest empty.
    func byFrameReport() -> StatsReport {
        var report = report([])
        report.rollGames = 4
        report.byFrame = (1...10).map {
            FrameStats(frameIndex: $0, strikes: Rate(hits: $0 == 1 ? 1 : 0, attempts: 4),
                       pins: Mean(total: $0 == 1 ? 30 : 0, count: 4))
        }
        return report
    }

    @Test func strikesByFrameBars() throws {
        guard case .byFrame(let content) = try card(.byFrameStrike, byFrameReport()).body else {
            Issue.record("byFrameStrike is not a by-frame chart")
            return
        }
        #expect(content.kind == .strikes)
        #expect(content.bars.map(\.frame) == Array(1...10))
        #expect(content.bars[0].value == 0.25)
        #expect(content.bars[0].text == "25%")
        #expect(content.bars[0].accessibilityLabel == "Frame 1, 25%")
        #expect(content.bars[1].value == 0)
        #expect(content.sample == "4 games")
    }

    @Test func averageByFrameBars() throws {
        guard case .byFrame(let content) = try card(.byFrameAverage, byFrameReport()).body else {
            Issue.record("byFrameAverage is not a by-frame chart")
            return
        }
        #expect(content.kind == .average)
        #expect(content.bars[0].value == 7.5)
        #expect(content.bars[0].text == "7.5")
        #expect(content.bars[0].accessibilityLabel == "Frame 1, 7.5 pins")
        #expect(content.sample == "4 games")
    }

    func whatIfReport(rewritten: Int, allMade: Int = 1232) -> StatsReport {
        var report = report([])
        report.pinGames = 6
        report.whatIfSinglePins = WhatIfSinglePins(actual: Mean(total: 1176, count: 6),
                                                   allMade: Mean(total: allMade, count: 6), rewritten: rewritten)
        return report
    }

    @Test func whatIfShowsTheGain() throws {
        #expect(try card(.whatIfSinglePins, whatIfReport(rewritten: 12)).body == .whatIf(WhatIfContent(
            actual: "196", allMade: "205.3", detail: "+9.3 pins a game · 12 missed single pins",
            accessibilityLabel: "What if, your average 196, 205.3 with every single-pin spare made, 9.3 more pins a game"
        )))
        guard case .whatIf(let one) = try card(.whatIfSinglePins, whatIfReport(rewritten: 1, allMade: 1185)).body else {
            Issue.record("whatIfSinglePins is not a what-if")
            return
        }
        #expect(one.detail == "+1.5 pins a game · 1 missed single pin")
    }

    @Test func whatIfWithNothingMissed() throws {
        #expect(try card(.whatIfSinglePins, whatIfReport(rewritten: 0, allMade: 1176)).body == .whatIf(WhatIfContent(
            actual: "196", allMade: "196", detail: "You made every single-pin spare.",
            accessibilityLabel: "What if, your average 196, you made every single-pin spare."
        )))
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
