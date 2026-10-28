import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct StatsFilterDraftTests {
    let store: BowlingStore

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    func owner(_ profile: StatsProfile) throws -> BowlerRecord {
        try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: profile)
    }

    /// One complete final-only game of `type` for `bowler`.
    func game(_ type: EventType, for bowler: BowlerID) throws {
        let id = try store.sessions.startSession(
            SessionMetadata(date: .now, eventType: type),
            bowlers: [(bowlerID: bowler, defaultBallID: nil)], entryMode: .finalOnly
        )
        let game = try #require(try store.sessions.session(id).bowlers.first?.games.first?.id)
        try store.games.setFinalScore(200, for: game)
    }

    func draft(_ eventTypes: Set<EventType>, _ date: DatePreset = .allTime) -> StatsFilterDraft {
        StatsFilterDraft(filter: StatsFilter(datePreset: date, eventTypes: eventTypes, bowlerID: BowlerID()), bowlerName: "Sam")
    }

    @Test func leagueOwnerWithLeagueGamesStartsOnCompetition() throws {
        let sam = try owner(.league)
        try game(.league, for: sam.id)
        let draft = StatsFilterDraft.defaults(for: sam, owner: sam, in: store)
        #expect(draft.scope == .competition)
        #expect(draft.chips == ["All time", "Competition", "Sam"])
        #expect(draft.filter.bowlerID == sam.id)
    }

    @Test func casualOwnerStartsOnAllGames() throws {
        let sam = try owner(.casual)
        try game(.league, for: sam.id)
        let draft = StatsFilterDraft.defaults(for: sam, owner: sam, in: store)
        #expect(draft.scope == .allGames)
        #expect(draft.chips[1] == "All games")
    }

    @Test func savedScopeWins() throws {
        _ = try owner(.league)
        try store.bowlers.setStatsScope(.all)
        let sam = try #require(store.bowlers.owner())
        try game(.league, for: sam.id)
        #expect(StatsFilterDraft.defaults(for: sam, owner: sam, in: store).scope == .allGames)
    }

    @Test func customChipListsTypesInFixedOrder() {
        let draft = draft([.league, .practice])
        #expect(draft.scope == .custom)
        #expect(draft.chips[1] == "Practice, League")
    }

    @Test func datePresetChips() {
        let chips = DatePreset.allCases.map { draft(Set(EventType.allCases), $0).chips[0] }
        #expect(chips == ["This week", "This month", "Last 30 days", "This season", "All time"])
    }

    @Test func cantApplyWithNoTypes() {
        #expect(!draft([]).canApply)
        #expect(draft([.casual]).canApply)
    }

    @Test func changingBowlerResetsTheScope() throws {
        let sam = try owner(.league)
        let ana = try store.bowlers.createBowler(name: "Ana")
        try game(.league, for: ana.id)
        var kept = StatsFilterDraft.defaults(for: sam, owner: sam, in: store)
        kept.filter.eventTypes = [.practice]
        kept.filter.datePreset = .thisMonth
        let changed = kept.changingBowler(to: ana, owner: sam, in: store)
        #expect(changed.filter.bowlerID == ana.id)
        #expect(changed.bowlerName == "Ana")
        #expect(changed.scope == .competition)
        #expect(changed.filter.datePreset == .thisMonth)
    }

    @Test func deletedBowlerFallsBackToTheOwner() throws {
        let sam = try owner(.league)
        let ana = try store.bowlers.createBowler(name: "Ana")
        let kept = StatsFilterDraft.defaults(for: ana, owner: sam, in: store)
        #expect(StatsFilterDraft.current(kept, in: store) == kept)
        try store.bowlers.deleteBowler(ana.id)
        let current = try #require(StatsFilterDraft.current(kept, in: store))
        #expect(current.filter.bowlerID == sam.id)
        #expect(current.bowlerName == "Sam")
    }

    @Test func noOwnerHasNoFilter() {
        #expect(StatsFilterDraft.current(nil, in: store) == nil)
    }

    @Test func firstLoadIsTheOwnersDefault() throws {
        let sam = try owner(.casual)
        #expect(StatsFilterDraft.current(nil, in: store) == StatsFilterDraft.defaults(for: sam, owner: sam, in: store))
    }
}
