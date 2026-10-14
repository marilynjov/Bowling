import Testing
import BowlingCore

@Suite struct StatsPresetTests {
    private static let casualCards: [StatsCardID] = [.average, .highGame, .trendChart, .strikePct, .sparePct]

    @Test func casualStatsCards() {
        #expect(StatsPreset.statsCards(for: .casual) == Self.casualCards)
    }

    // openPct is in the league preset but is a 1b card, so it is left out until 1b ships.
    @Test func leagueStatsCardsAreCasualsPlusLeagueCards() {
        #expect(StatsPreset.statsCards(for: .league) == Self.casualCards + [
            .highSeries, .leavesTable, .leftMostMadeLeast, .singlePinConversion,
        ])
    }

    @Test func competitiveStatsCardsAreEveryAvailableCardInCatalogOrder() {
        #expect(StatsPreset.statsCards(for: .competitive) == [
            .average, .highGame, .highSeries,
            .trendChart,
            .strikePct, .sparePct, .fouls,
            .leavesTable, .leftMostMadeLeast, .splitConversion, .makeableConversion, .singlePinConversion,
        ])
    }

    @Test func casualHomeTiles() {
        #expect(StatsPreset.homeTiles(for: .casual) == [.average, .highGame, .strikePct])
    }

    @Test(arguments: [StatsProfile.league, .competitive])
    func leagueAndCompetitiveHomeTiles(profile: StatsProfile) {
        #expect(StatsPreset.homeTiles(for: profile) == [.average, .highGame, .highSeries, .strikePct, .sparePct])
    }

    @Test func unknownProfileUsesTheCasualPreset() {
        #expect(StatsPreset.statsCards(for: .unknown) == StatsPreset.statsCards(for: .casual))
        #expect(StatsPreset.homeTiles(for: .unknown) == StatsPreset.homeTiles(for: .casual))
        #expect(StatsPreset.prefersCompetition(.unknown) == StatsPreset.prefersCompetition(.casual))
    }

    @Test(arguments: [
        (StatsProfile.casual, false),
        (.league, true),
        (.competitive, true),
        (.unknown, false),
    ])
    func defaultScope(profile: StatsProfile, competition: Bool) {
        #expect(StatsPreset.prefersCompetition(profile) == competition)
    }

    @Test(arguments: StatsProfile.allCases)
    func presetsOnlyContainAvailableCardsWithoutDuplicates(profile: StatsProfile) {
        for cards in [StatsPreset.statsCards(for: profile), StatsPreset.homeTiles(for: profile)] {
            #expect(!cards.isEmpty)
            #expect(cards.allSatisfy { $0.isAvailable })
            #expect(Set(cards).count == cards.count)
        }
    }
}
