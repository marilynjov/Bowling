import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct SettingsRowsTests {
    let store: BowlingStore

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    func owner(_ profile: StatsProfile = .league, hand: Handedness = .right) throws -> BowlerRecord {
        try store.bowlers.createOwner(name: "Sam", handedness: hand, statsProfile: profile)
    }

    @Test func profileSummaryNamesTheHand() throws {
        var sam = try owner()
        #expect(SettingsRows(owner: sam).profileSummary == "Sam · Right-handed")
        sam.handedness = .left
        #expect(SettingsRows(owner: sam).profileSummary == "Sam · Left-handed")
        sam.handedness = .unknown
        #expect(SettingsRows(owner: sam).profileSummary == "Sam")
    }

    @Test func followNamesWhatTheStylePicks() throws {
        var sam = try owner(.league)
        let league = SettingsRows(owner: sam)
        #expect(league.title(.follow) == "Follow bowling style (Competition)")
        #expect(league.title(.competition) == "Competition")
        #expect(league.title(.allGames) == "All games")
        sam.statsProfile = .casual
        #expect(SettingsRows(owner: sam).title(.follow) == "Follow bowling style (All games)")
    }

    @Test func defaultGamesFromTheScope() throws {
        var sam = try owner()
        let cases: [(StatsScope?, SettingsRows.DefaultGames)] = [
            (nil, .follow), (.competition, .competition), (.all, .allGames), (.unknown, .follow),
        ]
        for (scope, expected) in cases {
            sam.statsScope = scope
            #expect(SettingsRows(owner: sam).defaultGames == expected, "\(String(describing: scope))")
        }
        #expect(SettingsRows.DefaultGames.allCases.map(\.scope) == [nil, .competition, .all])
    }

    @Test func styleFromTheProfile() throws {
        var sam = try owner(.league)
        #expect(SettingsRows(owner: sam).style == .league)
        sam.statsProfile = .unknown
        #expect(SettingsRows(owner: sam).style == nil)
        #expect(SettingsRows.styles.map(SettingsRows.title) == ["Casual", "League", "Competitive"])
    }
}
