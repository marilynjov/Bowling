import Testing
import BowlingCore

@Suite struct StatsPresetTests {
    private static let casualCards: [StatsCardID] = [.average, .highGame, .trendChart, .strikePct, .sparePct]

    @Test func casualStatsCards() {
        #expect(StatsPreset.statsCards(for: .casual) == Self.casualCards)
    }

    @Test func leagueStatsCardsAreCasualsPlusLeagueCards() {
        #expect(StatsPreset.statsCards(for: .league) == Self.casualCards + [
            .highSeries, .leavesTable, .leftMostMadeLeast, .singlePinConversion, .openPct,
        ])
    }

    @Test func competitiveStatsCardsAreEveryCardInCatalogOrder() {
        #expect(StatsPreset.statsCards(for: .competitive) == [
            .average, .highGame, .highSeries,
            .trendChart,
            .strikePct, .sparePct, .fouls,
            .openPct, .cleanGamePct, .firstBallAverage, .headPinRate,
            .leavesTable, .leftMostMadeLeast, .splitConversion, .makeableConversion, .singlePinConversion,
            .byFrameStrike, .byFrameAverage,
            .whatIfSinglePins,
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
    func savedScopeWinsOverTheProfile(profile: StatsProfile) {
        #expect(StatsPreset.prefersCompetition(scope: .competition, profile: profile))
        #expect(!StatsPreset.prefersCompetition(scope: .all, profile: profile))
    }

    @Test(arguments: StatsProfile.allCases)
    func noSavedScopeFollowsTheProfile(profile: StatsProfile) {
        let byProfile = StatsPreset.prefersCompetition(profile)
        #expect(StatsPreset.prefersCompetition(scope: nil, profile: profile) == byProfile)
        #expect(StatsPreset.prefersCompetition(scope: .unknown, profile: profile) == byProfile)
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
