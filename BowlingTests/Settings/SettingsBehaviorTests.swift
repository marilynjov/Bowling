import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

/// #13's Done when: every setting changes the behavior it names.
@Suite struct SettingsBehaviorTests {
    let store: BowlingStore

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    func game(_ type: EventType, score: Int, for bowler: BowlerID) throws {
        let id = try store.sessions.startSession(
            SessionMetadata(date: .now, eventType: type),
            bowlers: [(bowlerID: bowler, defaultBallID: nil)], entryMode: .finalOnly
        )
        let game = try #require(try store.sessions.session(id).bowlers.first?.games.first?.id)
        try store.games.setFinalScore(score, for: game)
    }

    func averageSample() throws -> String? {
        try #require(HomeData.load(from: store).tiles.first { $0.card == .average }).sample
    }

    @Test func bowlingStyleChangesTheCards() throws {
        _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        #expect(HomeData.load(from: store).tiles.map(\.card) == StatsPreset.homeTiles(for: .league))
        try store.bowlers.setStatsProfile(.casual)
        let owner = try #require(store.bowlers.owner())
        #expect(HomeData.load(from: store).tiles.map(\.card) == StatsPreset.homeTiles(for: .casual))
        #expect(StatsPreset.displayedStatsCards(layout: owner.statsLayout, profile: owner.statsProfile)
            == StatsPreset.statsCards(for: .casual))
    }

    @Test func defaultGamesChangesWhereStatsStarts() throws {
        let sam = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        try game(.league, score: 200, for: sam.id)
        try game(.casual, score: 180, for: sam.id)
        #expect(try averageSample() == "1 game · All games 190")
        try store.bowlers.setStatsScope(SettingsRows.DefaultGames.allGames.scope)
        #expect(try averageSample() == "2 games")
        #expect(SettingsRows(owner: try #require(store.bowlers.owner())).defaultGames == .allGames)
    }

    @Test func followingTheStyleAgainRestoresIt() throws {
        let sam = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        try game(.league, score: 200, for: sam.id)
        try game(.casual, score: 180, for: sam.id)
        try store.bowlers.setStatsScope(SettingsRows.DefaultGames.allGames.scope)
        try store.bowlers.setStatsScope(SettingsRows.DefaultGames.follow.scope)
        #expect(try averageSample() == "1 game · All games 190")
        #expect(SettingsRows(owner: try #require(store.bowlers.owner())).defaultGames == .follow)
    }
}
