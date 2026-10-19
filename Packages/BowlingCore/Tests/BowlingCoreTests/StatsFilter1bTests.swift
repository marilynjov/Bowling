import Foundation
import Testing
import BowlingCore
import BowlingFixtures

/// Spec section 6 "Filters", 1b: custom dates, ball, oil pattern, center, league, against
/// the filter fixture. Fixture session dates, `now` being Wednesday 2026-10-14 12:00 UTC:
/// practice 13 Oct (1 day ago), sundayDoubles 11 Oct (3), tuesdayRecent 7 Oct (7),
/// tournament 2 Oct (12), tuesdayOpening 25 Aug (50), tuesdayLastSeason 28 Mar (200).
/// Tuesday Mixed's season is 15 Aug 2026 (60 days ago) through 11 Feb 2027 (120 ahead).
@Suite struct StatsFilter1bTests {
    let now = DemoFixture.referenceDate
    let calendar = StatsFilterTests.utc
    let owner = DemoBowler.owner.id

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// The season of `filter.leagueID`, as the repository looks it up.
    private func season(_ filter: StatsFilter) -> DateInterval? {
        FilterLeague.allCases.first { $0.id == filter.leagueID }?
            .season(relativeTo: now).map { DateInterval(start: $0.start, end: $0.end) }
    }

    private func matching(_ filter: StatsFilter) -> Set<FilterGame> {
        let games = FilterFixture.games(relativeTo: now)
        let ids = Set(games.filter { filter.matches($0, now: now, calendar: calendar, leagueSeason: season(filter)) }.map(\.id))
        return Set(FilterGame.allCases.filter { ids.contains($0.id) })
    }

    private static let ownerGames = Set(FilterGame.allCases.filter { $0.bowler == .owner })

    @Test func newFieldsDefaultToAny() {
        let filter = StatsFilter(bowlerID: owner)
        #expect(filter.customRange == nil)
        #expect(filter.ballID == nil && filter.oilPatternID == nil)
        #expect(filter.centerID == nil && filter.leagueID == nil)
        #expect(matching(filter) == Self.ownerGames)
    }

    // MARK: Custom date range

    @Test func customRangeCoversWholeCalendarDaysWithTheEndDayIncluded() {
        let filter = StatsFilter(customRange: day(2026, 10, 2, hour: 15)...day(2026, 10, 11, hour: 9), bowlerID: owner)
        #expect(filter.dateInterval(now: now, calendar: calendar)
                == DateInterval(start: day(2026, 10, 2), end: day(2026, 10, 12)))
        // 2 Oct tournament, 7 Oct Tuesday, 11 Oct Sunday; 13 Oct practice is after the end.
        #expect(matching(filter) == [.tournament1, .tuesdayRecent1, .tuesdayRecent2, .sundayDoubles1])
    }

    @Test func customRangeOfOneDay() {
        let filter = StatsFilter(customRange: day(2026, 10, 7, hour: 18)...day(2026, 10, 7, hour: 18), bowlerID: owner)
        #expect(matching(filter) == [.tuesdayRecent1, .tuesdayRecent2])
    }

    @Test func customRangeReplacesTheDatePreset() {
        // This week alone would be 11-17 Oct; the range 20 Aug-5 Oct wins.
        let filter = StatsFilter(datePreset: .thisWeek, customRange: day(2026, 8, 20)...day(2026, 10, 5), bowlerID: owner)
        #expect(matching(filter) == [.tuesdayOpening1, .tournament1])
    }

    @Test func customRangeIgnoresTheLeagueSeason() {
        let filter = StatsFilter(datePreset: .thisSeason, customRange: day(2026, 3, 1)...day(2026, 3, 31),
                                 bowlerID: owner, leagueID: FilterLeague.tuesdayMixed.id)
        #expect(matching(filter) == [.tuesdayLastSeason1])
    }

    // MARK: Custom date range in a local time zone

    private static let newYork: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func newYorkDay(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        Self.newYork.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// An owner game moved to `sessionDate`, matched against `filter` in New York.
    private func matchesInNewYork(_ filter: StatsFilter, sessionDate: Date) -> Bool {
        var game = FilterFixture.games(relativeTo: now).first { $0.id == FilterGame.tuesdayRecent1.id }!
        game.sessionDate = sessionDate
        return filter.matches(game, now: now, calendar: Self.newYork)
    }

    @Test func customRangeKeepsALateEveningGameOnTheLocalEndDay() {
        // 5-7 Oct picked in New York (EDT, UTC-4): 5 Oct 04:00 UTC to 8 Oct 04:00 UTC.
        let filter = StatsFilter(customRange: newYorkDay(2026, 10, 5)...newYorkDay(2026, 10, 7), bowlerID: owner)
        #expect(filter.dateInterval(now: now, calendar: Self.newYork)
                == DateInterval(start: day(2026, 10, 5, hour: 4), end: day(2026, 10, 8, hour: 4)))
        // 7 Oct 23:30 EDT is 8 Oct 03:30 UTC: already 8 Oct in UTC, still the end day locally.
        #expect(matchesInNewYork(filter, sessionDate: newYorkDay(2026, 10, 7, hour: 23, minute: 30)))
        // 8 Oct 00:30 EDT is 8 Oct 04:30 UTC, the day after the end.
        #expect(!matchesInNewYork(filter, sessionDate: newYorkDay(2026, 10, 8, hour: 0, minute: 30)))
    }

    @Test func customRangeAcrossTheEndOfDaylightSavingTime() {
        // US clocks fall back on Sun 1 Nov 2026, 02:00 EDT -> 01:00 EST. 29 Oct-2 Nov starts
        // at 29 Oct 00:00 EDT = 04:00 UTC and ends at 3 Nov 00:00 EST = 05:00 UTC:
        // 5 days of 24 h plus the repeated hour, 5 * 24 + 1 = 121 h.
        let filter = StatsFilter(customRange: newYorkDay(2026, 10, 29)...newYorkDay(2026, 11, 2), bowlerID: owner)
        let interval = filter.dateInterval(now: now, calendar: Self.newYork)
        #expect(interval == DateInterval(start: day(2026, 10, 29, hour: 4), end: day(2026, 11, 3, hour: 5)))
        #expect(interval?.duration == TimeInterval(121 * 3600))
        // 2 Nov 23:30 EST is 3 Nov 04:30 UTC, inside; a fixed 5 * 24 h from the start would
        // end at 3 Nov 04:00 UTC and drop it.
        #expect(matchesInNewYork(filter, sessionDate: newYorkDay(2026, 11, 2, hour: 23, minute: 30)))
        // 3 Nov 00:30 EST is 3 Nov 05:30 UTC, the day after the end.
        #expect(!matchesInNewYork(filter, sessionDate: newYorkDay(2026, 11, 3, hour: 0, minute: 30)))
    }

    // MARK: Ball

    @Test func ballMatchesTheDefaultBall() {
        let filter = StatsFilter(bowlerID: owner, ballID: DemoBall.ownerStrike.id)
        #expect(matching(filter) == [.tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1])
    }

    @Test func ballMatchesAnyRollOverride() {
        // tuesdayRecent1: one override on the frame 10 spare; sundayDoubles1: no default
        // ball, one override in frame 1; tournament1: the default ball.
        let filter = StatsFilter(bowlerID: owner, ballID: DemoBall.ownerSpare.id)
        #expect(matching(filter) == [.tuesdayRecent1, .sundayDoubles1, .tournament1])
    }

    @Test func ballCombinesWithBowler() {
        #expect(matching(StatsFilter(bowlerID: DemoBowler.partner.id, ballID: DemoBall.partnerStrike.id))
                == [.tuesdayRecentPartner])
        #expect(matching(StatsFilter(bowlerID: owner, ballID: DemoBall.partnerStrike.id)).isEmpty)
        #expect(matching(StatsFilter(bowlerID: owner, ballID: UUID())).isEmpty)
    }

    // MARK: Center, pattern, league

    @Test func centerKeepsSessionsAtThatCenter() {
        #expect(matching(StatsFilter(bowlerID: owner, centerID: FilterCenter.northLanes.id))
                == [.tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1, .tuesdayLastSeason1])
        #expect(matching(StatsFilter(bowlerID: owner, centerID: FilterCenter.southBowl.id))
                == [.sundayDoubles1, .tournament1])
    }

    @Test func oilPatternKeepsSessionsOnThatPattern() {
        #expect(matching(StatsFilter(bowlerID: owner, oilPatternID: FilterPattern.houseShot.id))
                == [.tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1])
        #expect(matching(StatsFilter(bowlerID: owner, oilPatternID: FilterPattern.cheetah.id))
                == [.tuesdayLastSeason1, .tournament1])
    }

    @Test func leagueKeepsThatLeaguesSessions() {
        #expect(matching(StatsFilter(bowlerID: owner, leagueID: FilterLeague.tuesdayMixed.id))
                == [.tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1, .tuesdayLastSeason1])
        #expect(matching(StatsFilter(bowlerID: owner, leagueID: FilterLeague.sundayDoubles.id))
                == [.sundayDoubles1])
    }

    @Test func thisSeasonUsesTheFilteredLeaguesDates() {
        // 15 Aug-11 Feb keeps 7 Oct and 25 Aug and drops 28 Mar, which the nine-month
        // fallback (14 Jan-14 Oct) would keep.
        let filter = StatsFilter(datePreset: .thisSeason, bowlerID: owner, leagueID: FilterLeague.tuesdayMixed.id)
        #expect(filter.dateInterval(now: now, calendar: calendar, leagueSeason: season(filter))
                == DateInterval(start: day(2026, 8, 15), end: day(2027, 2, 12)))
        #expect(matching(filter) == [.tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1])
    }

    @Test func thisSeasonFallsBackToNineMonthsForALeagueWithoutDates() {
        let filter = StatsFilter(datePreset: .thisSeason, bowlerID: owner, leagueID: FilterLeague.sundayDoubles.id)
        #expect(filter.dateInterval(now: now, calendar: calendar, leagueSeason: season(filter))
                == DateInterval(start: day(2026, 1, 14), end: day(2026, 10, 15)))
        #expect(matching(filter) == [.sundayDoubles1])
    }

    @Test func thisSeasonWithoutALeagueKeepsTheLastNineMonths() {
        // 14 Jan-14 Oct holds every owner game, 28 Mar included.
        #expect(matching(StatsFilter(datePreset: .thisSeason, bowlerID: owner)) == Self.ownerGames)
    }

    // MARK: Combinations

    @Test func filtersCombine() {
        let spare = DemoBall.ownerSpare.id
        #expect(matching(StatsFilter(bowlerID: owner, ballID: spare, centerID: FilterCenter.southBowl.id))
                == [.sundayDoubles1, .tournament1])
        #expect(matching(StatsFilter(eventTypes: [.league], bowlerID: owner, ballID: spare,
                                     centerID: FilterCenter.southBowl.id)) == [.sundayDoubles1])
        #expect(matching(StatsFilter(bowlerID: owner, ballID: spare, oilPatternID: FilterPattern.houseShot.id))
                == [.tuesdayRecent1])
        // Last 30 days is 15 Sep-14 Oct, which drops tuesdayOpening1 (25 Aug).
        #expect(matching(StatsFilter(datePreset: .last30Days, bowlerID: owner, ballID: DemoBall.ownerStrike.id))
                == [.tuesdayRecent1, .tuesdayRecent2])
        #expect(matching(StatsFilter(bowlerID: owner, oilPatternID: FilterPattern.cheetah.id,
                                     centerID: FilterCenter.northLanes.id)) == [.tuesdayLastSeason1])
        #expect(matching(StatsFilter(datePreset: .thisSeason, bowlerID: owner,
                                     oilPatternID: FilterPattern.cheetah.id,
                                     leagueID: FilterLeague.tuesdayMixed.id)).isEmpty)
    }

    /// Hand-read from the fixture tables: the owner games each single value keeps.
    static let byBall: [BallID?: Set<FilterGame>] = [
        nil: ownerGames,
        DemoBall.ownerStrike.id: [.tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1],
        DemoBall.ownerSpare.id: [.tuesdayRecent1, .sundayDoubles1, .tournament1],
        DemoBall.partnerStrike.id: [],
    ]
    static let byCenter: [CenterID?: Set<FilterGame>] = [
        nil: ownerGames,
        FilterCenter.northLanes.id: [.tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1, .tuesdayLastSeason1],
        FilterCenter.southBowl.id: [.sundayDoubles1, .tournament1],
    ]
    static let byPattern: [OilPatternID?: Set<FilterGame>] = [
        nil: ownerGames,
        FilterPattern.houseShot.id: [.tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1],
        FilterPattern.cheetah.id: [.tuesdayLastSeason1, .tournament1],
    ]
    static let byLeague: [LeagueID?: Set<FilterGame>] = [
        nil: ownerGames,
        FilterLeague.tuesdayMixed.id: [.tuesdayRecent1, .tuesdayRecent2, .tuesdayOpening1, .tuesdayLastSeason1],
        FilterLeague.sundayDoubles.id: [.sundayDoubles1],
    ]

    /// Filters are a conjunction, so every combination keeps the intersection of what each
    /// value keeps alone: 4 balls * 3 centers * 3 patterns * 3 leagues = 108 filters.
    @Test func everyBallCenterPatternLeagueCombination() {
        for (ball, byBallGames) in Self.byBall {
            for (center, byCenterGames) in Self.byCenter {
                for (pattern, byPatternGames) in Self.byPattern {
                    for (league, byLeagueGames) in Self.byLeague {
                        let filter = StatsFilter(bowlerID: owner, ballID: ball, oilPatternID: pattern,
                                                 centerID: center, leagueID: league)
                        let expected = byBallGames.intersection(byCenterGames)
                            .intersection(byPatternGames).intersection(byLeagueGames)
                        #expect(matching(filter) == expected, "\(filter)")
                    }
                }
            }
        }
    }

    // MARK: Codable

    @Test func roundTripsEveryFieldThroughCodable() throws {
        let filter = StatsFilter(
            datePreset: .thisSeason, eventTypes: [.league], customRange: day(2026, 9, 1)...day(2026, 9, 30),
            bowlerID: owner, ballID: DemoBall.ownerSpare.id, oilPatternID: FilterPattern.cheetah.id,
            centerID: FilterCenter.southBowl.id, leagueID: FilterLeague.sundayDoubles.id)
        let data = try JSONEncoder().encode(filter)
        #expect(try JSONDecoder().decode(StatsFilter.self, from: data) == filter)
    }

    @Test func aFilterSavedBy1aDecodesWithTheNewFieldsUnset() throws {
        let saved = #"{"datePreset":"thisMonth","eventTypes":["league"],"bowlerID":"\#(owner.uuidString)"}"#
        let filter = try JSONDecoder().decode(StatsFilter.self, from: Data(saved.utf8))
        #expect(filter == StatsFilter(datePreset: .thisMonth, eventTypes: [.league], bowlerID: owner))
    }
}
