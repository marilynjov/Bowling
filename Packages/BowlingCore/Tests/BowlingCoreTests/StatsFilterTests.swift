import Foundation
import Testing
import BowlingCore
import BowlingFixtures

/// Spec section 6 "Filters", 1a: date presets, event types, bowler.
@Suite struct StatsFilterTests {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Wednesday 2026-10-14 12:00 UTC.
    let now = DemoFixture.referenceDate
    let calendar = Self.utc

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func interval(_ preset: DatePreset, season: DateInterval? = nil) -> DateInterval? {
        StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: preset)
            .dateInterval(now: now, calendar: calendar, leagueSeason: season)
    }

    // MARK: Date presets

    @Test func allTimeHasNoInterval() {
        #expect(interval(.allTime) == nil)
    }

    @Test func thisWeekIsTheCalendarWeekContainingNow() {
        // Gregorian weeks start on Sunday: Sunday 11 October through Saturday 17 October.
        #expect(interval(.thisWeek) == DateInterval(start: day(2026, 10, 11), end: day(2026, 10, 18)))
    }

    @Test func thisWeekFollowsTheCalendarsFirstWeekday() {
        var monday = calendar
        monday.firstWeekday = 2
        let resolved = StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .thisWeek)
            .dateInterval(now: now, calendar: monday)
        #expect(resolved == DateInterval(start: day(2026, 10, 12), end: day(2026, 10, 19)))
    }

    @Test func thisMonthIsTheCalendarMonthContainingNow() {
        #expect(interval(.thisMonth) == DateInterval(start: day(2026, 10, 1), end: day(2026, 11, 1)))
    }

    @Test func last30DaysIsTodayAndTheTwentyNineDaysBefore() {
        #expect(interval(.last30Days) == DateInterval(start: day(2026, 9, 15), end: day(2026, 10, 15)))
    }

    @Test func thisSeasonWithoutALeagueIsTheLastNineMonths() {
        #expect(interval(.thisSeason) == DateInterval(start: day(2026, 1, 14), end: day(2026, 10, 15)))
    }

    @Test func thisSeasonUsesLeagueDatesWithTheEndDayIncluded() {
        let season = DateInterval(start: day(2026, 9, 1).addingTimeInterval(3600 * 19),
                                  end: day(2027, 4, 30).addingTimeInterval(3600 * 19))
        #expect(interval(.thisSeason, season: season)
                == DateInterval(start: day(2026, 9, 1), end: day(2027, 5, 1)))
    }

    @Test func leagueSeasonOnlyAffectsThisSeason() {
        let season = DateInterval(start: day(2026, 9, 1), end: day(2027, 4, 30))
        #expect(interval(.thisMonth, season: season) == interval(.thisMonth))
        #expect(interval(.allTime, season: season) == nil)
    }

    @Test func presetsResolveInTheCalendarsTimeZone() {
        // 12:00 UTC on 14 October is already 15 October in Auckland (UTC+13).
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        let resolved = StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .last30Days)
            .dateInterval(now: now, calendar: auckland)
        #expect(resolved?.end == auckland.date(from: DateComponents(year: 2026, month: 10, day: 16)))
    }

    // MARK: Matching the demo fixture

    private func matching(_ filter: StatsFilter) -> Set<GameID> {
        let games = DemoFixture.games(relativeTo: now)
        return Set(games.filter { filter.matches($0, now: now, calendar: calendar) }.map(\.id))
    }

    private func ids(_ games: DemoGame...) -> Set<GameID> {
        Set(games.map(\.id))
    }

    private static let ownerGames = DemoGame.allCases.filter { $0.bowler == .owner }

    @Test func defaultFilterIsAllTimeAndAllEventTypes() {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id)
        #expect(filter.datePreset == .allTime)
        #expect(filter.eventTypes == Set(EventType.allCases))
    }

    @Test func bowlerFilterKeepsOnlyThatBowlersGames() {
        #expect(matching(StatsFilter(bowlerID: DemoBowler.owner.id)) == Set(Self.ownerGames.map(\.id)))
        #expect(matching(StatsFilter(bowlerID: DemoBowler.partner.id))
                == ids(.leagueNightPartner1, .leagueNightPartner2, .leagueNightPartner3))
    }

    @Test func competitionKeepsLeagueAndTournamentGames() {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id, eventTypes: EventType.competition)
        #expect(matching(filter) == ids(
            .leagueNight1, .leagueNight2, .leagueNight3,
            .tournament1, .tournament2, .tournament3, .tournament4,
            .earlyLeague1, .earlyLeague2, .earlyLeague3))
    }

    @Test func customEventTypeCombination() {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id, eventTypes: [.practice, .casual])
        #expect(matching(filter) == ids(.practice1, .practice2, .casualOuting1, .casualOuting2, .practiceInProgress))
    }

    @Test func noEventTypesMatchesNothing() {
        #expect(matching(StatsFilter(bowlerID: DemoBowler.owner.id, eventTypes: [])).isEmpty)
    }

    @Test func thisWeekKeepsSessionsFromSundayOn() {
        // practiceInProgress (today), leagueNight (2 days ago); practice is 5 days ago.
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .thisWeek)
        #expect(matching(filter) == ids(.practiceInProgress, .leagueNight1, .leagueNight2, .leagueNight3))
    }

    @Test func thisMonthDropsSeptemberSessions() {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .thisMonth)
        #expect(matching(filter) == ids(
            .practiceInProgress, .leagueNight1, .leagueNight2, .leagueNight3, .practice1, .practice2,
            .tournament1, .tournament2, .tournament3, .tournament4))
    }

    @Test func last30DaysDropsTheCasualOutingFortyDaysAgo() {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .last30Days)
        #expect(matching(filter) == Set(Self.ownerGames.filter { $0.session != .casualOuting }.map(\.id)))
    }

    @Test func thisSeasonWithoutALeagueKeepsEveryDemoGame() {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .thisSeason)
        #expect(matching(filter) == Set(Self.ownerGames.map(\.id)))
    }

    @Test func filtersCombine() {
        let filter = StatsFilter(bowlerID: DemoBowler.friend.id, datePreset: .thisWeek, eventTypes: [.casual])
        #expect(matching(filter) == ids(.friendCasual1, .friendCasual2))
    }

    @Test func unknownEventTypeOnlyMatchesWhenSelected() {
        var game = DemoFixture.games(relativeTo: now)[0]
        game.eventType = .unknown
        let competition = StatsFilter(bowlerID: DemoBowler.owner.id, eventTypes: EventType.competition)
        #expect(!competition.matches(game, now: now, calendar: calendar))
        #expect(StatsFilter(bowlerID: DemoBowler.owner.id).matches(game, now: now, calendar: calendar))
    }

    @Test func roundTripsThroughCodable() throws {
        let filter = StatsFilter(bowlerID: DemoBowler.owner.id, datePreset: .thisSeason, eventTypes: [.league])
        let data = try JSONEncoder().encode(filter)
        #expect(try JSONDecoder().decode(StatsFilter.self, from: data) == filter)
    }
}
