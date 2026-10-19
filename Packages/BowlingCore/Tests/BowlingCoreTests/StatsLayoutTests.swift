import Testing
import BowlingCore

/// Spec section 7 "Customize" and "Layout rules", section 9 Phase 1b "Stats layout".
@Suite struct StatsLayoutTests {
    // MARK: Display

    // An empty layout means the surface's preset (spec section 3.2 Bowler).
    @Test(arguments: StatsProfile.allCases)
    func emptyLayoutShowsThePreset(profile: StatsProfile) {
        #expect(StatsPreset.displayedStatsCards(layout: [], profile: profile) == StatsPreset.statsCards(for: profile))
        #expect(StatsPreset.displayedHomeTiles(layout: [], profile: profile) == StatsPreset.homeTiles(for: profile))
    }

    // Empty Stats and Home layouts fall back to their own presets: league Stats starts
    // average, highGame, trendChart; league Home starts average, highGame, highSeries.
    @Test func eachSurfaceFallsBackToItsOwnPreset() {
        #expect(StatsPreset.displayedStatsCards(layout: [], profile: .league).prefix(3) == [.average, .highGame, .trendChart])
        #expect(StatsPreset.displayedHomeTiles(layout: [], profile: .league).prefix(3) == [.average, .highGame, .highSeries])
    }

    @Test func savedLayoutIsShownInItsOrder() {
        let layout = ["sparePct", "average", "leavesTable"]
        #expect(StatsPreset.displayedStatsCards(layout: layout, profile: .competitive) == [.sparePct, .average, .leavesTable])
        #expect(StatsPreset.displayedHomeTiles(layout: layout, profile: .casual) == [.sparePct, .average, .leavesTable])
    }

    // "futureCard" is not a StatsCardID: it was saved by a newer app version.
    @Test func unknownCardIDsAreSkipped() {
        let layout = ["futureCard", "average", "anotherFutureCard", "strikePct"]
        #expect(StatsPreset.displayedStatsCards(layout: layout, profile: .casual) == [.average, .strikePct])
        #expect(StatsPreset.displayedHomeTiles(layout: layout, profile: .casual) == [.average, .strikePct])
    }

    // whatIfSinglePins is a 1b card this build cannot render yet, so it is skipped like
    // an unknown ID.
    @Test func unavailableCardsAreSkipped() throws {
        try #require(!StatsCardID.whatIfSinglePins.isAvailable)
        #expect(StatsPreset.displayedStatsCards(layout: ["whatIfSinglePins", "fouls"], profile: .casual) == [.fouls])
    }

    // A screen lists each card once; the first occurrence keeps its place.
    @Test func repeatedCardsAreShownOnce() {
        let layout = ["average", "strikePct", "average"]
        #expect(StatsPreset.displayedStatsCards(layout: layout, profile: .casual) == [.average, .strikePct])
    }

    // A layout with nothing this build can show would leave the screen blank, so it shows
    // the preset instead.
    @Test func layoutWithOnlyUnknownCardsShowsThePreset() {
        #expect(StatsPreset.displayedStatsCards(layout: ["futureCard"], profile: .league) == StatsPreset.statsCards(for: .league))
        #expect(StatsPreset.displayedHomeTiles(layout: ["futureCard"], profile: .league) == StatsPreset.homeTiles(for: .league))
    }

    // MARK: Save

    @Test func savingOverAPresetWritesTheCards() {
        #expect(StatsPreset.layoutToSave([.sparePct, .average], replacing: []) == ["sparePct", "average"])
    }

    // Saved: average, futureA, strikePct, futureB. The user moves strikePct first.
    // Each unknown ID stays right after the known card it followed:
    // strikePct, futureB, average, futureA.
    @Test func unknownCardIDsAreKeptAfterTheCardTheyFollowed() {
        let previous = ["average", "futureA", "strikePct", "futureB"]
        #expect(StatsPreset.layoutToSave([.strikePct, .average], replacing: previous)
            == ["strikePct", "futureB", "average", "futureA"])
    }

    // Unknown IDs before every known card stay at the front.
    @Test func leadingUnknownCardIDsStayFirst() {
        let previous = ["futureA", "average", "strikePct"]
        #expect(StatsPreset.layoutToSave([.strikePct, .average, .fouls], replacing: previous)
            == ["futureA", "strikePct", "average", "fouls"])
    }

    // Saved: average, highGame, futureA, sparePct. The user removes highGame, so futureA
    // moves up to follow average, the nearest earlier card still in the layout:
    // average, futureA, sparePct.
    @Test func unknownIDAfterARemovedCardFollowsTheCardBeforeIt() {
        let previous = ["average", "highGame", "futureA", "sparePct"]
        #expect(StatsPreset.layoutToSave([.average, .sparePct], replacing: previous)
            == ["average", "futureA", "sparePct"])
    }

    // A card this build cannot show is preserved like an unknown ID.
    @Test func unavailableCardsAreKeptOnSave() throws {
        try #require(!StatsCardID.whatIfSinglePins.isAvailable)
        #expect(StatsPreset.layoutToSave([.fouls], replacing: ["whatIfSinglePins", "fouls"]) == ["whatIfSinglePins", "fouls"])
    }

    // Passing an unavailable card does not write it a second time: whatIfSinglePins is
    // kept once from previous (leading, before fouls), and the passed copy is dropped,
    // so the result is whatIfSinglePins, fouls.
    @Test func unavailableCardsPassedInAreNotWrittenTwice() throws {
        try #require(!StatsCardID.whatIfSinglePins.isAvailable)
        #expect(StatsPreset.layoutToSave([.fouls, .whatIfSinglePins], replacing: ["whatIfSinglePins", "fouls"])
            == ["whatIfSinglePins", "fouls"])
    }

    @Test func savedCardsAreWrittenOnce() {
        #expect(StatsPreset.layoutToSave([.average, .fouls, .average], replacing: []) == ["average", "fouls"])
    }

    // Display then save with no edits writes the stored layout back unchanged.
    @Test func unchangedLayoutRoundTrips() {
        let previous = ["futureA", "sparePct", "futureB", "average", "whatIfSinglePins"]
        let shown = StatsPreset.displayedStatsCards(layout: previous, profile: .casual)
        #expect(shown == [.sparePct, .average])
        #expect(StatsPreset.layoutToSave(shown, replacing: previous) == previous)
    }
}
