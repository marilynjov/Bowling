import Foundation
import Testing
import BowlingCore
import BowlingFixtures

/// §6 "Default scope": Competition only when the bowler has a complete league or
/// tournament game, otherwise All games.
@Suite struct StatsDefaultScopeTests {
    private let games = DemoFixture.games(relativeTo: DemoFixture.referenceDate)
    private let allGames = Set(EventType.allCases)

    @Test func ownerWhoPrefersCompetitionGetsCompetition() {
        let scope = StatsEngine.defaultEventTypes(games: games, bowler: DemoBowler.owner.id, preferCompetition: true)
        #expect(scope == DemoFixtureExpected.ownerCompetition.eventTypes)
    }

    @Test func ownerWhoPrefersAllGamesGetsAllGames() {
        let scope = StatsEngine.defaultEventTypes(games: games, bowler: DemoBowler.owner.id, preferCompetition: false)
        #expect(scope == allGames)
    }

    @Test func bowlerWithoutCompetitionGamesFallsBackToAllGames() {
        let scope = StatsEngine.defaultEventTypes(games: games, bowler: DemoBowler.friend.id, preferCompetition: true)
        #expect(scope == DemoFixtureExpected.friendAllGames.eventTypes)
    }

    @Test func incompleteCompetitionGameDoesNotCount() {
        var unfinished = games.first { $0.id == DemoGame.friendCasual1.id }!
        unfinished.eventType = .league
        unfinished.isComplete = false
        let scope = StatsEngine.defaultEventTypes(games: games + [unfinished], bowler: DemoBowler.friend.id,
                                                  preferCompetition: true)
        #expect(scope == allGames)
    }

    @Test func otherBowlersCompetitionGamesDoNotCount() {
        let partnerOnly = games.filter { $0.bowlerID == DemoBowler.partner.id }
        let scope = StatsEngine.defaultEventTypes(games: partnerOnly, bowler: DemoBowler.friend.id,
                                                  preferCompetition: true)
        #expect(scope == allGames)
    }
}
