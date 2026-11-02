import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct ProfileDraftTests {
    let store: BowlingStore
    let sam: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        sam = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
    }

    @Test func blankNameCantSave() {
        var draft = ProfileDraft(owner: sam)
        #expect(draft.canSave)
        draft.name = ""
        #expect(!draft.canSave)
        draft.name = "   "
        #expect(!draft.canSave)
        draft.name = "Ana"
        #expect(draft.canSave)
    }

    @Test func saveRenamesAndSetsTheHand() throws {
        var draft = ProfileDraft(owner: sam)
        #expect(draft.name == "Sam")
        #expect(draft.handedness == .right)
        draft.name = " Ana "
        draft.handedness = .left
        try draft.save(to: store.bowlers)
        let owner = try #require(store.bowlers.owner())
        #expect(owner.name == "Ana")
        #expect(owner.handedness == .left)
    }

    @Test func unknownHandStartsUnpicked() throws {
        var record = sam
        record.handedness = .unknown
        var draft = ProfileDraft(owner: record)
        #expect(draft.handedness == nil)
        #expect(draft.canSave)
        draft.name = "Ana"
        try draft.save(to: store.bowlers)
        #expect(store.bowlers.owner()?.handedness == .right)
    }
}
