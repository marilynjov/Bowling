import Foundation
import SwiftData
import Testing
import BowlingCore
import BowlingFixtures
@testable import BowlingData

/// The SwiftData side of the 1b filters (spec section 6 "Filters"): the fetch selects
/// exactly the filter fixture games `StatsFilter.matches` selects, with `thisSeason` taking
/// the filtered league's stored season.
@MainActor @Suite struct StatsRepository1bTests {
    let now = DemoFixture.referenceDate
    let calendar = StatsRepositoryTests.utc
    let store: BowlingStore
    var context: ModelContext { store.context }

    init() throws {
        store = try BowlingStore(inMemory: true)
        try insertFilterFixture(into: store.context, now: now)
    }

    private func fetch(_ filter: StatsFilter) -> [GameRecord] {
        store.stats.games(matching: filter, now: now, calendar: calendar)
    }

    private func expected(_ filter: StatsFilter) -> [GameRecord] {
        let season = FilterLeague.allCases.first { $0.id == filter.leagueID }?
            .season(relativeTo: now).map { DateInterval(start: $0.start, end: $0.end) }
        return FilterFixture.games(relativeTo: now)
            .filter { filter.matches($0, now: now, calendar: calendar, leagueSeason: season) }
            .sorted { ($0.sessionDate, $0.gameIndex) < ($1.sessionDate, $1.gameIndex) }
    }

    private func ids(_ games: FilterGame...) -> [GameID] {
        games.map(\.id)
    }

    static let balls: [BallID?] = [nil] + DemoBall.allCases.map(\.id) + [UUID()]
    static let centers: [CenterID?] = [nil] + FilterCenter.allCases.map(\.id)
    static let patterns: [OilPatternID?] = [nil] + FilterPattern.allCases.map(\.id)
    static let leagues: [LeagueID?] = [nil] + FilterLeague.allCases.map(\.id)
    static let customRange: ClosedRange<Date> = {
        let calendar = StatsRepositoryTests.utc
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 23))!
        return start...end
    }()

    /// Every ball, center, pattern, and league value of the fixture, plus an unknown ball,
    /// for each bowler with games, date preset, and the custom range.
    @Test(arguments: [DemoBowler.owner, .partner], DatePreset.allCases.map { $0 as DatePreset? } + [nil])
    func predicateAgreesWithInMemoryFilter(bowler: DemoBowler, preset: DatePreset?) {
        for ball in Self.balls {
            for center in Self.centers {
                for pattern in Self.patterns {
                    for league in Self.leagues {
                        let filter = StatsFilter(
                            datePreset: preset ?? .allTime, customRange: preset == nil ? Self.customRange : nil,
                            bowlerID: bowler.id, ballID: ball, oilPatternID: pattern, centerID: center, leagueID: league)
                        #expect(fetch(filter) == expected(filter), "\(filter)")
                    }
                }
            }
        }
    }

    @Test func ballMatchesOverridesInTheStore() {
        // Sorted by date: tournament 2 Oct, tuesdayRecent 7 Oct, sundayDoubles 11 Oct.
        let games = fetch(StatsFilter(bowlerID: DemoBowler.owner.id, ballID: DemoBall.ownerSpare.id))
        #expect(games.map(\.id) == ids(.tournament1, .tuesdayRecent1, .sundayDoubles1))
    }

    @Test func recordsCarryTheSessionsCenterLeagueAndPattern() throws {
        let games = fetch(StatsFilter(bowlerID: DemoBowler.owner.id, leagueID: FilterLeague.tuesdayMixed.id))
        let recent = try #require(games.first { $0.id == FilterGame.tuesdayRecent1.id })
        #expect(recent.centerID == FilterCenter.northLanes.id)
        #expect(recent.leagueID == FilterLeague.tuesdayMixed.id)
        #expect(recent.oilPatternID == FilterPattern.houseShot.id)
    }

    @Test func thisSeasonUsesTheFilteredLeaguesStoredDates() {
        // 15 Aug-11 Feb: 25 Aug and 7 Oct, not 28 Mar.
        let filter = StatsFilter(datePreset: .thisSeason, bowlerID: DemoBowler.owner.id,
                                 leagueID: FilterLeague.tuesdayMixed.id)
        #expect(fetch(filter).map(\.id) == ids(.tuesdayOpening1, .tuesdayRecent1, .tuesdayRecent2))
    }

    @Test func thisSeasonFallsBackToNineMonthsWhenTheLeagueLacksADate() throws {
        // Only an end date, so the season is unset and 14 Jan-14 Oct applies: 28 Mar stays.
        try context.league(FilterLeague.tuesdayMixed.id).seasonStart = nil
        try context.save()
        let filter = StatsFilter(datePreset: .thisSeason, bowlerID: DemoBowler.owner.id,
                                 leagueID: FilterLeague.tuesdayMixed.id)
        #expect(fetch(filter).map(\.id)
                == ids(.tuesdayLastSeason1, .tuesdayOpening1, .tuesdayRecent1, .tuesdayRecent2))
    }

    @Test func thisSeasonIgnoresAReversedSeason() throws {
        let league = try context.league(FilterLeague.tuesdayMixed.id)
        (league.seasonStart, league.seasonEnd) = (league.seasonEnd, league.seasonStart)
        try context.save()
        let filter = StatsFilter(datePreset: .thisSeason, bowlerID: DemoBowler.owner.id,
                                 leagueID: FilterLeague.tuesdayMixed.id)
        #expect(fetch(filter).map(\.id)
                == ids(.tuesdayLastSeason1, .tuesdayOpening1, .tuesdayRecent1, .tuesdayRecent2))
    }

    @Test func unknownLeagueMatchesNothing() {
        #expect(fetch(StatsFilter(datePreset: .thisSeason, bowlerID: DemoBowler.owner.id, leagueID: UUID())).isEmpty)
    }
}

/// Inserts the filter fixture's centers, leagues (with their seasons), patterns, and games
/// under their fixture IDs, with each session tagged as `FilterSession` says.
@MainActor
func insertFilterFixture(into context: ModelContext, now: Date) throws {
    for fixture in FilterCenter.allCases {
        let center = BowlingCenter(name: fixture.name)
        center.id = fixture.id
        context.insert(center)
    }
    for fixture in FilterPattern.allCases {
        let pattern = OilPattern(name: fixture.name)
        pattern.id = fixture.id
        context.insert(pattern)
    }
    for fixture in FilterLeague.allCases {
        let league = League(name: fixture.name)
        league.id = fixture.id
        context.insert(league)
        league.center = try context.center(fixture.center.id)
        league.seasonStart = fixture.season(relativeTo: now)?.start
        league.seasonEnd = fixture.season(relativeTo: now)?.end
    }
    try context.save()
    for record in FilterFixture.games(relativeTo: now) {
        let session = try #require(try insertGame(record, into: context).session)
        let fixture = try #require(FilterSession.allCases.first { $0.id == record.sessionID })
        session.center = try fixture.center.map { try context.center($0.id) }
        session.league = try fixture.league.map { try context.league($0.id) }
        session.oilPattern = try fixture.oilPattern.map { try context.oilPattern($0.id) }
    }
    try context.save()
}
