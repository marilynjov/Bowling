import BowlingCore
import BowlingFixtures
import Foundation
import Testing
@testable import BowlingData

/// §6 "Leave occurrences" through the store: the filter selects the games, as for the
/// leaves table, and each occurrence comes back with game, session, frame, and ball.
@MainActor @Suite struct LeaveOccurrenceQueryTests {
    let now = DemoFixture.referenceDate
    let calendar = StatsRepositoryTests.utc
    let store: BowlingStore

    init() throws {
        store = try BowlingStore.demo(now: now)
    }

    private func occurrences(of pins: [Int], _ preset: DatePreset, _ eventTypes: Set<EventType>,
                             bowler: DemoBowler = .owner) -> [LeaveOccurrence] {
        let filter = StatsFilter(datePreset: preset, eventTypes: eventTypes, bowlerID: bowler.id)
        return store.stats.leaveOccurrences(of: LeaveClassifier.classify(PinSet(pins: pins)),
                                            matching: filter, now: now, calendar: calendar)
    }

    // The owner's competition "10" row has count 6, 4 made: leagueNight3 F10, leagueNight1
    // F10 and F1 (2 days ago), earlyLeague2 F9, F3, F2 (16 days ago). Only leagueNight1 F1's
    // spare roll overrides the default ownerStrike, with ownerSpare.
    @Test func allTimeListsEveryOccurrenceNewestFirst() {
        let found = occurrences(of: [10], .allTime, EventType.competition)
        #expect(found.map(\.game.gameID) == [
            DemoGame.leagueNight3, .leagueNight1, .leagueNight1,
            .earlyLeague2, .earlyLeague2, .earlyLeague2,
        ].map(\.id))
        #expect(found.map(\.frameIndex) == [10, 10, 1, 9, 3, 2])
        #expect(found.map(\.isConverted) == [true, true, true, false, true, false])
        #expect(found.map(\.ballID) == [
            DemoBall.ownerStrike, .ownerStrike, .ownerSpare, .ownerStrike, .ownerStrike, .ownerStrike,
        ].map(\.id))
        #expect(found.map(\.game.sessionID) == [
            DemoSession.leagueNight, .leagueNight, .leagueNight, .earlyLeague, .earlyLeague, .earlyLeague,
        ].map(\.id))
        #expect(found.map(\.gameIndex) == [3, 1, 1, 2, 2, 2])
    }

    // This week holds only leagueNight (2 days ago) and the incomplete practice, so the
    // three earlyLeague2 occurrences drop out: 6 - 3 = 3.
    @Test func theDateFilterNarrowsTheOccurrences() {
        let found = occurrences(of: [10], .thisWeek, EventType.competition)
        #expect(found.map(\.frameIndex) == [10, 10, 1])
        #expect(Set(found.map(\.game.sessionID)) == [DemoSession.leagueNight.id])
    }

    // The friend's "10" row: friendCasual1 F7 and F1, both made, with no ball set.
    @Test func otherBowlersSeeOnlyTheirOwnOccurrences() {
        let found = occurrences(of: [10], .allTime, Set(EventType.allCases), bowler: .friend)
        #expect(found.map(\.game.gameID) == [DemoGame.friendCasual1.id, DemoGame.friendCasual1.id])
        #expect(found.map(\.frameIndex) == [7, 1])
        #expect(found.allSatisfy { $0.ballID == nil && $0.isConverted })
    }
}
