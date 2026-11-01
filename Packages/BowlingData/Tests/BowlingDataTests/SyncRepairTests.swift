import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// §3.4 "Games with no bowler" and "Repair order", through `repairSyncedData()`.
@MainActor @Suite struct SyncRepairTests {
    let store: BowlingStore
    var context: ModelContext { store.context }
    let owner: BowlerRecord
    let friendID: UUID
    let session: SessionID
    let calendar = Calendar(identifier: .gregorian)

    /// The owner and a friend bowl one league session, finalOnly, lineup owner then friend.
    init() throws {
        store = try BowlingStore(inMemory: true)
        owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let friend = try store.bowlers.createBowler(name: "Alex")
        friendID = friend.id
        session = try store.sessions.startSession(
            SessionMetadata(date: DemoFixture.referenceDate, eventType: .league),
            bowlers: [(owner.id, nil), (friend.id, nil)], entryMode: .finalOnly
        )
        for game in try allGames() { try store.games.setFinalScore(200, for: game.id) }
    }

    private func allGames() throws -> [Game] {
        try context.fetch(FetchDescriptor<Game>())
    }

    private func friendsGame() throws -> Game {
        try #require(try allGames().first { $0.bowlerID == friendID })
    }

    private func ownersStats() -> [GameID] {
        store.stats.games(matching: StatsFilter(bowlerID: owner.id), now: .now, calendar: calendar).map(\.id)
    }

    /// As on a device that received the friend's game but not the friend's Bowler row.
    private func removeFriendsRow() throws {
        context.delete(try context.bowler(friendID))
        try context.save()
    }

    /// The import-order case from #89: the game lands before its bowler, stays unassigned
    /// and out of the owner's stats, then links to the bowler once the row arrives.
    @Test func aGameThatArrivesBeforeItsBowlerLinksToItLater() throws {
        let game = try friendsGame()
        let lineup = try allGames().map { [$0.lineupIndex, $0.gameIndex] }.sorted { $0.lexicographicallyPrecedes($1) }
        let ownerStats = ownersStats()
        try removeFriendsRow()
        let updatedAt = game.updatedAt

        try store.repairSyncedData()

        #expect(game.bowler == nil)
        #expect(game.bowlerID == friendID)
        #expect(ownersStats() == ownerStats)

        let arrived = Bowler(name: "Alex")
        arrived.id = friendID
        context.insert(arrived)
        try context.save()

        try store.repairSyncedData()

        #expect(game.bowler === arrived)
        #expect(game.updatedAt == updatedAt)
        #expect(ownersStats() == ownerStats)
        #expect(try allGames().map { [$0.lineupIndex, $0.gameIndex] }.sorted { $0.lexicographicallyPrecedes($1) } == lineup)
        #expect(try store.sessions.session(session).bowlers.map(\.bowler.id) == [owner.id, friendID])
    }

    /// A bowler deleted on another device never comes back: the game stays unassigned and
    /// counts in no one's stats.
    @Test func aGameWhoseBowlerNeverArrivesStaysUnassigned() throws {
        let game = try friendsGame()
        let ownerStats = ownersStats()
        try removeFriendsRow()

        try store.repairSyncedData()
        try store.repairSyncedData()

        #expect(game.bowler == nil)
        #expect(game.bowlerID == friendID)
        #expect(ownersStats() == ownerStats)
        #expect(try store.sessions.session(session).bowlers.map(\.bowler.id) == [owner.id])
    }

    /// A game with no bowler and no `bowlerID` was never anyone else's: the owner claims it.
    @Test func aGameWithNoBowlerIDGoesToTheOwner() throws {
        let game = try friendsGame()
        game.assign(nil)
        try context.save()

        try store.repairSyncedData()

        #expect(game.bowlerID == owner.id)
        #expect(ownersStats().contains(game.id))
    }

    @Test func duplicateGamesAreDeletedAndReported() throws {
        let original = try friendsGame()
        let copy = Game(gameIndex: original.gameIndex, entryMode: .finalOnly)
        context.insert(copy)
        copy.session = original.session
        copy.assign(original.bowler)
        copy.finalScore = 180
        copy.isComplete = true
        copy.updatedAt = original.updatedAt.addingTimeInterval(-60)
        try context.save()

        let result = try store.repairSyncedData()

        #expect(result == SyncRepairResult(deletedGames: [copy.id]))
        #expect(try allGames().count == 2)
    }

    @Test func aSecondRunChangesNothing() throws {
        let game = try friendsGame()
        game.assign(nil)
        try context.save()
        try store.repairSyncedData()

        let result = try store.repairSyncedData()

        #expect(result == SyncRepairResult())
        #expect(!context.hasChanges)
    }
}
