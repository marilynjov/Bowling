import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct BowlerArchiveTests {
    let store: BowlingStore
    var bowlers: BowlerRepository { store.bowlers }
    let owner: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
    }

    @Test func anArchivedFriendLeavesTheListButStaysInTheFullOne() throws {
        let alex = try bowlers.createBowler(name: "Alex")
        let zoe = try bowlers.createBowler(name: "Zoe")
        try bowlers.setArchived(true, for: alex.id)

        #expect(bowlers.bowlers().map(\.name) == ["Sam", "Zoe"])
        let all = bowlers.bowlers(includingArchived: true)
        #expect(all.map(\.name) == ["Sam", "Alex", "Zoe"])
        #expect(all.map(\.isArchived) == [false, true, false])
        #expect(zoe.isArchived == false)
    }

    @Test func unarchivingBringsTheFriendBack() throws {
        let alex = try bowlers.createBowler(name: "Alex")
        try bowlers.setArchived(true, for: alex.id)
        try bowlers.setArchived(false, for: alex.id)
        #expect(bowlers.bowlers().map(\.name) == ["Sam", "Alex"])
        #expect(bowlers.bowlers().allSatisfy { !$0.isArchived })
    }

    @Test func archivingKeepsTheGamesInHistoryAndStats() throws {
        let alex = try bowlers.createBowler(name: "Alex")
        let sessionID = try store.sessions.startSession(
            SessionMetadata(date: .now, eventType: .league),
            bowlers: [(owner.id, nil), (alex.id, nil)], entryMode: .countOnly
        )
        try bowlers.setArchived(true, for: alex.id)

        let detail = try store.sessions.session(sessionID)
        #expect(detail.bowlers.map(\.bowler.name) == ["Sam", "Alex"])
        #expect(detail.bowlers.last?.bowler.isArchived == true)
        #expect(try store.context.fetchCount(FetchDescriptor<Game>()) == 2)
    }

    @Test func settingTheSameStateLeavesUpdatedAtAlone() throws {
        let alex = try bowlers.createBowler(name: "Alex")
        let model = try store.context.bowler(alex.id)
        let before = model.updatedAt
        try bowlers.setArchived(false, for: alex.id)
        #expect(model.updatedAt == before)
        try bowlers.setArchived(true, for: alex.id)
        #expect(model.updatedAt > before)
    }

    @Test func theOwnerCannotBeArchived() throws {
        #expect(throws: RepositoryError.cannotArchiveOwner) { try bowlers.setArchived(true, for: owner.id) }
        #expect(throws: RepositoryError.cannotArchiveOwner) { try bowlers.setArchived(false, for: owner.id) }
        #expect(bowlers.bowlers().first?.isArchived == false)
    }

    @Test func anUnknownBowlerIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try bowlers.setArchived(true, for: BowlerID()) }
    }
}
