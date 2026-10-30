import BowlingCore
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct BowlerDeleteTests {
    let store: BowlingStore
    var bowlers: BowlerRepository { store.bowlers }
    let owner: BowlerRecord
    let alex: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        alex = try store.bowlers.createBowler(name: "Alex")
    }

    @discardableResult
    func startSession(_ lineup: [BowlerID]) throws -> SessionID {
        try store.sessions.startSession(
            SessionMetadata(date: .now, eventType: .league),
            bowlers: lineup.map { ($0, nil) }, entryMode: .countOnly
        )
    }

    func count<T: PersistentModel>(_ type: T.Type) -> Int {
        (try? store.context.fetchCount(FetchDescriptor<T>())) ?? -1
    }

    @Test func aPlainDeleteOfAFriendWithGamesIsStillRefused() throws {
        try startSession([owner.id, alex.id])
        try startSession([alex.id])
        #expect(throws: RepositoryError.bowlerHasGames(count: 2)) { try bowlers.deleteBowler(alex.id) }
        #expect(throws: RepositoryError.bowlerHasGames(count: 2)) {
            try bowlers.deleteBowler(alex.id, includingGames: false)
        }
        #expect(count(Bowler.self) == 2)
        #expect(count(Game.self) == 3)
    }

    @Test func includingGamesDeletesTheFriendAndTheirGamesOnly() throws {
        let shared = try startSession([owner.id, alex.id])
        try startSession([alex.id])
        let ownerOnly = try startSession([owner.id])

        try bowlers.deleteBowler(alex.id, includingGames: true)

        #expect(bowlers.bowlers(includingArchived: true).map(\.name) == ["Sam"])
        // The owner's games in the shared and owner-only sessions remain: 2.
        #expect(count(Game.self) == 2)
        let remaining = try store.context.fetch(FetchDescriptor<Game>())
        #expect(remaining.allSatisfy { $0.bowler?.id == owner.id })
        // Alex's only session had no other games and is gone; the other two stay.
        #expect(Set(try store.context.fetch(FetchDescriptor<Session>()).map(\.id)) == [shared, ownerOnly])
        #expect(try store.sessions.session(shared).bowlers.map(\.bowler.name) == ["Sam"])
    }

    @Test func includingGamesCascadesFramesAndRolls() throws {
        let session = try startSession([alex.id])
        let gameID = try #require(try store.sessions.session(session).bowlers.first?.games.first?.id)
        _ = try store.games.recordRoll(.count(7), ballID: nil, in: gameID)
        #expect(count(Roll.self) == 1)

        try bowlers.deleteBowler(alex.id, includingGames: true)
        #expect(count(Game.self) == 0)
        #expect(count(Frame.self) == 0)
        #expect(count(Roll.self) == 0)
        #expect(count(Session.self) == 0)
    }

    @Test func anArchivedFriendCanBeDeletedWithEverything() throws {
        try startSession([alex.id])
        try bowlers.setArchived(true, for: alex.id)
        try bowlers.deleteBowler(alex.id, includingGames: true)
        #expect(count(Bowler.self) == 1)
        #expect(count(Game.self) == 0)
    }

    @Test func aFriendWithoutGamesIsDeletedEitherWay() throws {
        try bowlers.deleteBowler(alex.id, includingGames: true)
        #expect(count(Bowler.self) == 1)
    }

    @Test func theOwnerCanNeverBeDeleted() throws {
        try startSession([owner.id])
        #expect(throws: RepositoryError.cannotDeleteOwner) { try bowlers.deleteBowler(owner.id, includingGames: true) }
        #expect(count(Game.self) == 1)
        #expect(count(Bowler.self) == 2)
    }

    @Test func anUnknownBowlerIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try bowlers.deleteBowler(BowlerID(), includingGames: true) }
    }
}
