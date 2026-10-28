import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct SessionDetailsDraftTests {
    let metadata = SessionMetadata(
        date: Date(timeIntervalSince1970: 1_800_000_000), eventType: .league,
        centerID: UUID(), leagueID: UUID(), oilPatternID: UUID(), lanes: "13–14", notes: "Fresh oil"
    )

    @Test func startsFromSavedMetadata() {
        let draft = SessionDetailsDraft(metadata)
        #expect(draft.centerID == metadata.centerID)
        #expect(draft.leagueID == metadata.leagueID)   // init must not clear it
        #expect(draft.lanes == "13–14")
    }

    @Test func savingKeepsUntouchedFields() {
        var draft = SessionDetailsDraft(metadata)
        draft.notes = "Dry"
        var expected = metadata
        expected.notes = "Dry"
        #expect(draft.metadata == expected)
    }

    @Test func theLeagueFollowsTheCenter() {
        var draft = SessionDetailsDraft(metadata)
        draft.centerID = UUID()
        #expect(draft.leagueID == nil)
    }

    @Test func onlyLeagueNightsKeepTheLeague() {
        var draft = SessionDetailsDraft(metadata)
        draft.eventType = .practice
        #expect(draft.metadata.leagueID == nil)
    }
}
