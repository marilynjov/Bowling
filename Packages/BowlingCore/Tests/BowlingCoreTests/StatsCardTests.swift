import Foundation
import Testing
import BowlingCore

@Suite struct StatsCardTests {
    @Test func rawValuesAreTheStoredIDsInCatalogOrder() {
        #expect(StatsCardID.allCases.map(\.rawValue) == [
            "average", "highGame", "highSeries",
            "trendChart",
            "strikePct", "sparePct", "fouls",
            "openPct", "cleanGamePct", "firstBallAverage", "headPinRate",
            "leavesTable", "leftMostMadeLeast", "splitConversion", "makeableConversion", "singlePinConversion",
            "byFrameStrike", "byFrameAverage",
            "whatIfSinglePins",
        ])
    }

    @Test func cardsRoundTripThroughCodable() throws {
        for card in StatsCardID.allCases {
            let decoded = try JSONDecoder().decode(StatsCardID.self, from: JSONEncoder().encode(card))
            #expect(decoded == card)
        }
    }

    @Test func groupsFollowTheCatalog() {
        let grouped = Dictionary(grouping: StatsCardID.allCases, by: \.group)
        #expect(grouped[.overview] == [.average, .highGame, .highSeries])
        #expect(grouped[.trend] == [.trendChart])
        #expect(grouped[.strikesAndSpares] == [
            .strikePct, .sparePct, .fouls, .openPct, .cleanGamePct, .firstBallAverage, .headPinRate,
        ])
        #expect(grouped[.leaves] == [
            .leavesTable, .leftMostMadeLeast, .splitConversion, .makeableConversion, .singlePinConversion,
        ])
        #expect(grouped[.byFrame] == [.byFrameStrike, .byFrameAverage])
        #expect(grouped[.whatIf] == [.whatIfSinglePins])
    }

    // 1b shipped, so every Phase 1 card is in presets and layouts.
    @Test func everyPhase1CardIsAvailable() {
        #expect(StatsCardID.allCases.allSatisfy { $0.isAvailable })
    }
}
