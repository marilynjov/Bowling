import Foundation
import SwiftData
import Testing
import BowlingCore
import BowlingFixtures
@testable import BowlingData

/// The SwiftData side of spec section 6 "Filters": the fetch must select exactly the games
/// `StatsFilter.matches` selects from the same fixture, in contract order.
@MainActor @Suite struct StatsFilterQueryTests {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    let now = DemoFixture.referenceDate
    let calendar = Self.utc
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try BowlingStore.makeContainer(inMemory: true)
        context = ModelContext(container)
        try DemoStoreSeed.insertDemoGames(relativeTo: now, into: context)
    }

    private func fetch(_ filter: StatsFilter, seasonLeague: LeagueID? = nil) throws -> [GameRecord] {
        try StatsFilterQuery.games(matching: filter, seasonLeague: seasonLeague,
                                   now: now, calendar: calendar, in: context)
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
            let filter = StatsFilter(bowlerID: bowler.id, datePreset: preset, eventTypes: eventTypes)
            #expect(try fetch(filter) == expected(filter), "\(eventTypes)")
        }
    }

    @Test func returnsFullRecordsSortedBySessionDateThenGameIndex() throws {
        let games = try fetch(StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .thisWeek))
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

        let filter = StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .thisSeason)
        let games = try fetch(filter, seasonLeague: league.id)
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

        let filter = StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .thisSeason)
        #expect(try fetch(filter, seasonLeague: league.id) == expected(filter))
        #expect(try fetch(filter, seasonLeague: UUID()) == expected(filter))
    }

    @Test func storedEventTypeFromANewerVersionMatchesOnlyAllGames() throws {
        let session = try context.fetch(FetchDescriptor<Session>()).first { $0.id == DemoSession.tournament.id }!
        session.eventType = "fun-league"
        try context.save()

        let competition = try fetch(StatsFilter(bowlerID: DemoBowler.owner.id, eventTypes: EventType.competition))
        #expect(!competition.contains { $0.sessionID == DemoSession.tournament.id })

        let all = try fetch(StatsFilter(bowlerID: DemoBowler.owner.id))
        let tournament = all.filter { $0.sessionID == DemoSession.tournament.id }
        #expect(tournament.count == 4)
        #expect(tournament.allSatisfy { $0.eventType == .unknown })

        let onlyUnknown = try fetch(StatsFilter(bowlerID: DemoBowler.owner.id, eventTypes: [.unknown]))
        #expect(onlyUnknown.map(\.id) == tournament.map(\.id))
    }

    @Test func gamesWithoutASessionOrBowlerAreLeftOut() throws {
        let orphan = Game(gameIndex: 1, entryMode: .finalOnly)
        orphan.isComplete = true
        orphan.finalScore = 200
        context.insert(orphan)
        orphan.bowler = try context.fetch(FetchDescriptor<Bowler>()).first { $0.isOwner }
        let noBowler = Game(gameIndex: 9, entryMode: .finalOnly)
        context.insert(noBowler)
        noBowler.session = try context.fetch(FetchDescriptor<Session>()).first
        try context.save()

        let games = try fetch(StatsFilter(bowlerID: DemoBowler.owner.id))
        #expect(!games.contains { $0.id == orphan.id || $0.id == noBowler.id })
    }
}
