import BowlingCore
import BowlingFixtures
import Foundation
import Testing
@testable import BowlingData

@MainActor @Suite struct DemoStoreTests {
    let now = DemoFixture.referenceDate
    let store: BowlingStore

    init() throws {
        store = try BowlingStore.demo(now: now)
    }

    @Test func bowlersAreTheFixtureBowlersOwnerFirst() {
        #expect(store.bowlers.owner()?.id == DemoBowler.owner.id)
        #expect(store.bowlers.bowlers().map(\.id) == [DemoBowler.owner.id, DemoBowler.partner.id, DemoBowler.friend.id])
        #expect(store.bowlers.bowlers().map(\.name) == ["Sam Rivera", "Alex Chen", "Jordan Lee"])
    }

    @Test func ballsAreTheFixtureBalls() {
        let balls = store.balls.activeBalls()
        #expect(Set(balls.map(\.id)) == Set(DemoBall.allCases.map(\.id)))
        for ball in DemoBall.allCases {
            let summary = balls.first { $0.id == ball.id }
            #expect(summary?.name == ball.name)
            #expect(summary?.intendedRole == ball.role)
        }
    }

    @Test func sessionsAreTheFixtureSessionsNewestFirst() {
        let expected = DemoSession.allCases.sorted { $0.daysAgo < $1.daysAgo }
        let sessions = store.sessions.sessions()
        #expect(sessions.map(\.id) == expected.map(\.id))
        for (summary, session) in zip(sessions, expected) {
            #expect(summary.eventType == session.eventType)
            #expect(summary.date == Calendar(identifier: .gregorian).date(byAdding: .day, value: -session.daysAgo, to: now))
        }
    }

    @Test func everyGameMatchesItsFixtureRecord() throws {
        for expected in DemoFixture.games(relativeTo: now) {
            #expect(try store.games.game(expected.id) == expected)
        }
    }

    @Test func leagueNightListsTheOwnerThenThePartnerWithThreeGamesEach() throws {
        let detail = try store.sessions.session(DemoSession.leagueNight.id)
        #expect(detail.bowlers.map(\.bowler.id) == [DemoBowler.owner.id, DemoBowler.partner.id])
        #expect(detail.bowlers.map { $0.games.map(\.id) } == [
            [DemoGame.leagueNight1.id, DemoGame.leagueNight2.id, DemoGame.leagueNight3.id],
            [DemoGame.leagueNightPartner1.id, DemoGame.leagueNightPartner2.id, DemoGame.leagueNightPartner3.id],
        ])
    }

    @Test func theIncompletePracticeIsResumable() {
        #expect(store.sessions.resumableSession()?.id == DemoSession.practiceInProgress.id)
    }

    @Test func statsSeeTheOwnersGames() {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id)
        let games = store.stats.games(matching: filter, now: now, calendar: Calendar(identifier: .gregorian))
        let expected = DemoFixture.games(relativeTo: now).filter { $0.bowlerID == DemoBowler.owner.id }
        #expect(Set(games.map(\.id)) == Set(expected.map(\.id)))
    }

    @Test func eachCallIsAFreshStore() throws {
        let other = try BowlingStore.demo(now: now)
        try other.games.deleteGame(DemoGame.tournament1.id)
        #expect((try? store.games.game(DemoGame.tournament1.id)) != nil)
    }
}
