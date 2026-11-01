import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct StatTileContentTests {
    let report = PreviewData.report

    @Test func strikeTileFromTheReport() throws {
        let tile = try #require(StatTileContent.make(.strikePct, report))
        #expect(tile.title == "Strike %")
        #expect(tile.value == StatFormat.percent(report.strikes))
        #expect(tile.sample == StatFormat.sample(report.strikes.attempts, .frames))
        #expect(tile.progress == report.strikes.value)
    }

    @Test func conversionTilesCountLeaves() throws {
        let tile = try #require(StatTileContent.make(.splitConversion, report))
        #expect(tile.title == "Split conversion %")
        #expect(tile.sample == StatFormat.sample(report.splitConversion.attempts, .leaves))
        #expect(tile.progress == report.splitConversion.value)
    }

    @Test func firstBallTilesCountFirstBalls() throws {
        let average = try #require(StatTileContent.make(.firstBallAverage, report))
        #expect(average.title == "First-ball average")
        #expect(average.value == StatFormat.average(report.firstBallAverage))
        #expect(average.sample == StatFormat.sample(report.firstBallAverage.count, .firstBalls))
        #expect(average.progress == nil)
        let headPin = try #require(StatTileContent.make(.headPinRate, report))
        #expect(headPin.title == "Head pin %")
        #expect(headPin.sample == StatFormat.sample(report.headPin.attempts, .firstBalls))
    }

    @Test func nonTileCardsAreNil() {
        let cards: [StatsCardID] = [.trendChart, .leavesTable, .leftMostMadeLeast, .byFrameStrike, .byFrameAverage, .whatIfSinglePins]
        for card in cards {
            #expect(StatTileContent.make(card, report) == nil, "\(card)")
        }
    }
}
