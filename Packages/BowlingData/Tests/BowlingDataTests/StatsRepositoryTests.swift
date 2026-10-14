import Foundation
import SwiftData
import Testing
import BowlingCore
import BowlingFixtures
@testable import BowlingData

/// The SwiftData side of spec section 6 "Filters": the fetch must select exactly the games
/// `StatsFilter.matches` selects from the same fixture, in contract order. Also §6 "Default scope".
@MainActor @Suite struct StatsRepositoryTests {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    let now = DemoFixture.referenceDate
    let calendar = Self.utc
    let store: BowlingStore
    var context: ModelContext { store.context }

    init() throws {
        store = try BowlingStore(inMemory: true)
        for game in DemoFixture.games(relativeTo: now) {
            _ = try insertGame(game, into: store.context)
        }
    }

    private func fetch(_ filter: StatsFilter, seasonLeague: LeagueID? = nil) -> [GameRecord] {
        store.stats.games(matching: filter, seasonLeague: seasonLeague, now: now, calendar: calendar)
    }

    /// The fixture games the in-memory filter keeps, sorted by session date then game index.
    private func expected(_ filter: StatsFilter, season: DateInterval? = nil) -> [GameRecord] {
        DemoFixture.games(relativeTo: now)
            .filter { filter.matches($0, now: now, calendar: calendar, leagueSeason: season) }
            .sorted { ($0.sessionDate, $0.gameIndex) < ($1.sessionDate, $1.gameIndex) }
    }

    static let eventTypeSets: [Set<EventType>] = [
        Set(EventType.allCases), EventType.competition, [.practice], [.casual, .practice], [],
    ]

    @Test(arguments: DemoBowler.allCases, DatePreset.allCases)
    func predicateAgreesWithInMemoryFilter(bowler: DemoBowler, preset: DatePreset) throws {
        for eventTypes in Self.eventTypeSets {
            let filter = StatsFilter(datePreset: preset, eventTypes: eventTypes, bowlerID: bowler.id)
            #expect(fetch(filter) == expected(filter), "\(eventTypes)")
        }
    }

    @Test func returnsFullRecordsSortedBySessionDateThenGameIndex() throws {
        let games = fetch(StatsFilter(datePreset: .thisWeek, bowlerID: DemoBowler.owner.id))
        #expect(games.map(\.id) == [
            DemoGame.leagueNight1, .leagueNight2, .leagueNight3, .practiceInProgress,
        ].map(\.id))
        // Frames and rolls come back in index order with balls, masks, and fouls intact.
        let fixture = DemoFixture.games(relativeTo: now).first { $0.id == DemoGame.leagueNight1.id }
        #expect(games.first == fixture)
    }

    @Test func thisSeasonUsesTheLeaguesSeasonDates() throws {
        // 20 September to 10 October: earlyLeague (28 Sep), tournament (5 Oct), practice (9 Oct).
        let league = League(name: "Tuesday Mixed")
        league.seasonStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))
        league.seasonEnd = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10))
        context.insert(league)
        try context.save()

        let filter = StatsFilter(datePreset: .thisSeason, bowlerID: DemoBowler.owner.id)
        let games = fetch(filter, seasonLeague: league.id)
        #expect(games.map(\.id) == [
            DemoGame.earlyLeague1, .earlyLeague2, .earlyLeague3,
            .tournament1, .tournament2, .tournament3, .tournament4,
            .practice1, .practice2,
        ].map(\.id))
    }

    @Test func thisSeasonFallsBackToNineMonthsWhenTheLeagueLacksADate() throws {
        let league = League(name: "Summer")
        league.seasonStart = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))
        context.insert(league)
        try context.save()

        let filter = StatsFilter(datePreset: .thisSeason, bowlerID: DemoBowler.owner.id)
        #expect(fetch(filter, seasonLeague: league.id) == expected(filter))
        #expect(fetch(filter, seasonLeague: UUID()) == expected(filter))
    }

    @Test func storedEventTypeFromANewerVersionMatchesOnlyAllGames() throws {
        let session = try context.session(DemoSession.tournament.id)
        session.eventType = "fun-league"
        try context.save()

        let competition = fetch(StatsFilter(eventTypes: EventType.competition, bowlerID: DemoBowler.owner.id))
        #expect(!competition.contains { $0.sessionID == DemoSession.tournament.id })

        let all = fetch(StatsFilter(bowlerID: DemoBowler.owner.id))
        let tournament = all.filter { $0.sessionID == DemoSession.tournament.id }
        #expect(tournament.count == 4)
        #expect(tournament.allSatisfy { $0.eventType == .unknown })

        let onlyUnknown = fetch(StatsFilter(eventTypes: [.unknown], bowlerID: DemoBowler.owner.id))
        #expect(onlyUnknown.map(\.id) == tournament.map(\.id))
    }

    @Test func gamesWithoutASessionOrBowlerAreLeftOut() throws {
        let orphan = Game(gameIndex: 1, entryMode: .finalOnly)
        orphan.isComplete = true
        orphan.finalScore = 200
        context.insert(orphan)
        orphan.bowler = try context.bowler(DemoBowler.owner.id)
        let noBowler = Game(gameIndex: 9, entryMode: .finalOnly)
        context.insert(noBowler)
        noBowler.session = try context.fetch(FetchDescriptor<Session>()).first
        try context.save()

        let games = fetch(StatsFilter(bowlerID: DemoBowler.owner.id))
        #expect(!games.contains { $0.id == orphan.id || $0.id == noBowler.id })
    }

    @Test func contractOverloadUsesNineMonthsForThisSeason() {
        let filter = StatsFilter(datePreset: .thisSeason, bowlerID: DemoBowler.owner.id)
        #expect(store.stats.games(matching: filter, now: now, calendar: calendar) == expected(filter))
    }

    // MARK: Default scope

    @Test func defaultScopeIsCompetitionForABowlerWithCompetitionGames() {
        #expect(store.stats.defaultEventTypes(for: DemoBowler.owner.id, preferCompetition: true) == EventType.competition)
        #expect(store.stats.defaultEventTypes(for: DemoBowler.partner.id, preferCompetition: true) == EventType.competition)
    }

    @Test func defaultScopeIsAllGamesWhenNotPreferred() {
        #expect(store.stats.defaultEventTypes(for: DemoBowler.owner.id, preferCompetition: false) == Set(EventType.allCases))
    }

    @Test func defaultScopeFallsBackToAllGamesWithoutCompetitionGames() {
        #expect(store.stats.defaultEventTypes(for: DemoBowler.friend.id, preferCompetition: true) == Set(EventType.allCases))
        #expect(store.stats.defaultEventTypes(for: UUID(), preferCompetition: true) == Set(EventType.allCases))
    }

    @Test func incompleteCompetitionGamesDoNotSetTheDefaultScope() throws {
        let friendLeague = GameRecord(
            bowlerID: DemoBowler.friend.id, gameIndex: 1, entryMode: .pinByPin, finalScore: 0,
            isComplete: false, sessionDate: now, eventType: .league)
        _ = try insertGame(friendLeague, into: context)
        #expect(store.stats.defaultEventTypes(for: DemoBowler.friend.id, preferCompetition: true) == Set(EventType.allCases))
    }
}
