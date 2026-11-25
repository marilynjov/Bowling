import BowlingCore
import Testing
@testable import Bowling

@Suite struct StatsCardTextTests {
    @Test func everyCardHasADistinctTitleAndADescription() {
        let titles = StatsCardID.allCases.map(StatsCardText.title)
        #expect(Set(titles).count == titles.count)
        for card in StatsCardID.allCases {
            #expect(!StatsCardText.description(card).isEmpty, "\(card)")
            #expect(StatsCardText.title(card) != card.rawValue, "\(card)")
        }
    }

    @Test func titlesMatchTheCardsOnStats() {
        #expect(StatsCardText.title(.trendChart) == "Trend")
        #expect(StatsCardText.title(.average) == "Average")
        #expect(StatsCardText.title(.leftMostMadeLeast) == "Left most, made least")
    }

    @Test func everyGroupHasATitle() {
        #expect(StatsCardGroup.allCases.map(StatsCardText.title)
            == ["Overview", "Trend", "Strikes and spares", "Leaves", "By frame", "What if"])
    }
}
