import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// Spec section 7 "Customize" and "Layout rules", section 9 Phase 1b "Stats layout".
@MainActor @Suite struct BowlerLayoutTests {
    let store: BowlingStore
    var bowlers: BowlerRepository { store.bowlers }

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    private func storedOwner() throws -> Bowler {
        try #require(store.context.owner())
    }

    @Test func savedLayoutsRoundTrip() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try bowlers.setStatsLayout([.sparePct, .leavesTable, .average])
        try bowlers.setHomeLayout([.highGame, .strikePct])

        let owner = try #require(bowlers.owner())
        #expect(owner.statsLayout == ["sparePct", "leavesTable", "average"])
        #expect(owner.homeLayout == ["highGame", "strikePct"])
        #expect(StatsPreset.displayedStatsCards(layout: owner.statsLayout, profile: owner.statsProfile)
            == [.sparePct, .leavesTable, .average])
        #expect(StatsPreset.displayedHomeTiles(layout: owner.homeLayout, profile: owner.statsProfile)
            == [.highGame, .strikePct])
        // Stored as the comma-separated raw values of spec section 3.2.
        #expect(try storedOwner().statsLayout == "sparePct,leavesTable,average")
        #expect(try storedOwner().homeLayout == "highGame,strikePct")
    }

    // Saving the casual preset unedited stores "", so the owner keeps following the preset
    // and gets cards that become available later. Casual Stats is average, highGame,
    // trendChart, strikePct, sparePct; casual Home is average, highGame, strikePct.
    @Test func savingThePresetUneditedStoresEmpty() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try bowlers.setStatsLayout([.average, .highGame, .trendChart, .strikePct, .sparePct])
        try bowlers.setHomeLayout([.average, .highGame, .strikePct])
        #expect(try storedOwner().statsLayout == "")
        #expect(try storedOwner().homeLayout == "")
    }

    // The casual preset with average and highGame swapped, and Home without strikePct,
    // are edits, so they are stored as given.
    @Test func editedPresetIsStoredAsIs() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try bowlers.setStatsLayout([.highGame, .average, .trendChart, .strikePct, .sparePct])
        try bowlers.setHomeLayout([.average, .highGame])
        #expect(try storedOwner().statsLayout == "highGame,average,trendChart,strikePct,sparePct")
        #expect(try storedOwner().homeLayout == "average,highGame")
    }

    @Test func savingALayoutTouchesUpdatedAt() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        let before = Date.distantPast
        try storedOwner().updatedAt = before
        try bowlers.setStatsLayout([.average])
        #expect(try storedOwner().updatedAt > before)
    }

    @Test func savingKeepsUnknownCardIDs() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try storedOwner().statsLayout = "average,futureCard,strikePct"
        try storedOwner().homeLayout = "futureTile,highGame"

        let owner = try #require(bowlers.owner())
        let shown = StatsPreset.displayedStatsCards(layout: owner.statsLayout, profile: owner.statsProfile)
        #expect(shown == [.average, .strikePct])

        // The user moves strikePct first; futureCard stays after average, the card it followed.
        try bowlers.setStatsLayout([.strikePct, .average])
        // The user adds sparePct; futureTile stays first.
        try bowlers.setHomeLayout([.highGame, .sparePct])
        #expect(bowlers.owner()?.statsLayout == ["strikePct", "average", "futureCard"])
        #expect(bowlers.owner()?.homeLayout == ["futureTile", "highGame", "sparePct"])
    }

    @Test func resetStatsLayoutReturnsToThePresetAndLeavesHomeAlone() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        try bowlers.setStatsLayout([.fouls])
        try bowlers.setHomeLayout([.fouls])
        try bowlers.resetStatsLayout()

        let owner = try #require(bowlers.owner())
        #expect(owner.statsLayout == [])
        #expect(StatsPreset.displayedStatsCards(layout: owner.statsLayout, profile: .league)
            == StatsPreset.statsCards(for: .league))
        #expect(owner.homeLayout == ["fouls"])
    }

    @Test func resetHomeLayoutReturnsToThePresetAndLeavesStatsAlone() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        try bowlers.setStatsLayout([.fouls])
        try bowlers.setHomeLayout([.fouls])
        try bowlers.resetHomeLayout()

        let owner = try #require(bowlers.owner())
        #expect(owner.homeLayout == [])
        #expect(StatsPreset.displayedHomeTiles(layout: owner.homeLayout, profile: .league)
            == StatsPreset.homeTiles(for: .league))
        #expect(owner.statsLayout == ["fouls"])
    }

    // Changing the bowling style may replace both customized layouts with the new preset
    // (spec section 7 "Customize"). Unknown IDs go too: the user asked for the preset.
    @Test func resetLayoutsClearsBothIncludingUnknownCardIDs() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try storedOwner().statsLayout = "average,futureCard"
        try storedOwner().homeLayout = "futureTile"
        try bowlers.setStatsProfile(.competitive)
        try bowlers.resetLayouts()

        let owner = try #require(bowlers.owner())
        #expect(owner.statsLayout == [])
        #expect(owner.homeLayout == [])
        #expect(StatsPreset.displayedStatsCards(layout: owner.statsLayout, profile: owner.statsProfile)
            == StatsPreset.statsCards(for: .competitive))
    }

    // A style change alone keeps a customized layout; the app asks first (spec section 7).
    @Test func changingTheStyleKeepsACustomizedLayout() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try bowlers.setStatsLayout([.fouls])
        try bowlers.setStatsProfile(.league)
        #expect(bowlers.owner()?.statsLayout == ["fouls"])
    }

    @Test func layoutWritesWithoutAnOwnerThrowNotFound() {
        #expect(throws: RepositoryError.notFound) { try bowlers.setStatsLayout([.average]) }
        #expect(throws: RepositoryError.notFound) { try bowlers.setHomeLayout([.average]) }
        #expect(throws: RepositoryError.notFound) { try bowlers.resetStatsLayout() }
        #expect(throws: RepositoryError.notFound) { try bowlers.resetHomeLayout() }
        #expect(throws: RepositoryError.notFound) { try bowlers.resetLayouts() }
    }

    // Spec section 11: a customized layout survives a relaunch. A new context on the same
    // container sees only what was saved, not the first context's objects in memory.
    @Test func savedLayoutsAreReadBackByAFreshContext() throws {
        _ = try bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        try bowlers.setStatsLayout([.fouls, .average])
        try bowlers.setHomeLayout([.highGame])

        let relaunched = BowlerRepository(context: ModelContext(store.container))
        #expect(relaunched.owner()?.statsLayout == ["fouls", "average"])
        #expect(relaunched.owner()?.homeLayout == ["highGame"])
    }
}
