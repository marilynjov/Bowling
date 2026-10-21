import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// Spec §3.4 "Two owners": keep the oldest by `createdAt` (ties broken by the smaller UUID
/// string), move every game of the others to it, copy the non-empty fields it lacks, and
/// delete the others.
@MainActor @Suite struct OwnerMergeTests {
    let store: BowlingStore
    var context: ModelContext { store.context }

    static let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let idA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    static let idB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
    static let idC = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000003")!

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    @discardableResult
    private func insertOwner(_ id: UUID, name: String, createdAt: Date) -> Bowler {
        let owner = Bowler(name: name, isOwner: true)
        owner.id = id
        owner.createdAt = createdAt
        owner.updatedAt = createdAt
        context.insert(owner)
        return owner
    }

    @discardableResult
    private func insertGame(for bowler: Bowler, in session: Session, gameIndex: Int, lineupIndex: Int = 1) -> Game {
        let game = Game(gameIndex: gameIndex)
        context.insert(game)
        game.session = session
        game.assign(bowler)
        game.lineupIndex = lineupIndex
        return game
    }

    private func insertSession(daysAfterT0 days: Double) -> Session {
        let session = Session(date: Self.t0.addingTimeInterval(days * 86_400))
        context.insert(session)
        return session
    }

    private func owners() throws -> [Bowler] {
        try context.fetch(FetchDescriptor<Bowler>(predicate: #Predicate { $0.isOwner }))
    }

    private func games() throws -> [Game] {
        try context.fetch(FetchDescriptor<Game>())
    }

    // MARK: Two owners

    @Test func twoOwnersKeepTheOldestAndMoveTheNewerOnesGames() throws {
        // The older owner has the larger UUID string: createdAt decides before the UUID does.
        let older = insertOwner(Self.idB, name: "Sam", createdAt: Self.t0)
        let newer = insertOwner(Self.idA, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        let s1 = insertSession(daysAfterT0: 1)
        let s2 = insertSession(daysAfterT0: 2)
        insertGame(for: older, in: s1, gameIndex: 1)
        insertGame(for: older, in: s1, gameIndex: 2)
        insertGame(for: newer, in: s2, gameIndex: 1)
        try context.save()

        try store.mergeOwners()

        let remaining = try owners()
        #expect(remaining.map(\.id) == [Self.idB])
        // Bowler count: 2 owners - 1 deleted = 1.
        #expect(try context.fetchCount(FetchDescriptor<Bowler>()) == 1)
        // Games: 2 (kept) + 1 (moved) = 3, all on the kept owner; none deleted.
        let all = try games()
        #expect(all.count == 3)
        #expect(all.allSatisfy { $0.bowler?.id == Self.idB })
        // The moved game was alone for its bowler in s2, so it keeps gameIndex 1.
        #expect(all.first { $0.session === s2 }?.gameIndex == 1)
        // The kept owner's own name is non-empty, so "Samuel" is not copied.
        #expect(remaining.first?.name == "Sam")
    }

    @Test func copiesOnlyTheFieldsTheKeptOwnerLacks() throws {
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        older.handedness = Bowler.Handedness.right.rawValue
        older.statsLayout = "average,strikePct"
        // Lacking: handedness set, so kept; statsProfile unknown, email nil, homeLayout
        // empty, statsScope empty.
        let newer = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        newer.handedness = Bowler.Handedness.left.rawValue
        newer.statsProfile = Bowler.StatsProfile.league.rawValue
        newer.email = "sam@example.com"
        newer.statsLayout = "highGame"
        newer.homeLayout = "average,highSeries"
        newer.statsScope = "all"
        try context.save()

        try store.mergeOwners()

        let kept = try #require(try owners().first)
        #expect(kept.id == Self.idA)
        #expect(kept.name == "Sam")
        #expect(kept.handedness == "right")
        #expect(kept.statsLayout == "average,strikePct")
        #expect(kept.statsProfile == "league")
        #expect(kept.email == "sam@example.com")
        #expect(kept.homeLayout == "average,highSeries")
        #expect(kept.statsScope == "all")
    }

    @Test func emptyAndUnknownValuesAreNotCopied() throws {
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        older.statsScope = "competition"
        let newer = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        // Every value here means "not set", so none of them counts as non-empty.
        newer.handedness = Bowler.Handedness.unknown.rawValue
        newer.statsProfile = Bowler.StatsProfile.unknown.rawValue
        newer.email = ""
        newer.statsScope = "unknown"
        try context.save()

        try store.mergeOwners()

        let kept = try #require(try owners().first)
        #expect(kept.handedness == "unknown")
        #expect(kept.statsProfile == "unknown")
        #expect(kept.email == nil)
        #expect(kept.statsScope == "competition")
    }

    /// A newer app version can store a raw value this one does not know. It decodes as
    /// `.unknown` here, but it is a real value: only "" and "unknown" count as missing.
    @Test func unrecognisedRawValuesCountAsSet() throws {
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        older.handedness = "both"
        older.statsProfile = "senior"
        older.statsScope = "tournament"
        let newer = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        newer.handedness = Bowler.Handedness.left.rawValue
        newer.statsProfile = Bowler.StatsProfile.league.rawValue
        newer.statsScope = "all"
        try context.save()

        try store.mergeOwners()

        let kept = try #require(try owners().first)
        #expect(kept.handedness == "both")
        #expect(kept.statsProfile == "senior")
        #expect(kept.statsScope == "tournament")
    }

    @Test func unrecognisedRawValuesAreCopiedAsStored() throws {
        insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        let newer = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        newer.handedness = "both"
        newer.statsProfile = "senior"
        newer.statsScope = "tournament"
        try context.save()

        try store.mergeOwners()

        let kept = try #require(try owners().first)
        #expect(kept.handedness == "both")
        #expect(kept.statsProfile == "senior")
        #expect(kept.statsScope == "tournament")
    }

    @Test func nonOwnersAndTheirGamesAreLeftAlone() throws {
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        let newer = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        let friend = Bowler(name: "Alex")
        context.insert(friend)
        let session = insertSession(daysAfterT0: 1)
        insertGame(for: older, in: session, gameIndex: 1, lineupIndex: 1)
        insertGame(for: friend, in: session, gameIndex: 1, lineupIndex: 2)
        _ = newer
        try context.save()

        try store.mergeOwners()

        // Bowlers: Sam, Samuel, Alex = 3, minus Samuel = 2.
        #expect(try context.fetchCount(FetchDescriptor<Bowler>()) == 2)
        let friendGame = try #require(try games().first { $0.bowler?.name == "Alex" })
        #expect(friendGame.gameIndex == 1)
        #expect(friendGame.lineupIndex == 2)
        #expect(friend.isOwner == false)
    }

    // MARK: Three owners, tie on createdAt

    /// Insertion order must not change the result, so every device reaches the same one.
    @Test(arguments: [[0, 1, 2], [2, 1, 0], [1, 2, 0]])
    func threeOwnersBreakACreatedAtTieByTheSmallerUUIDString(order: [Int]) throws {
        // A and B share t0; "AAAAAAAA-..." < "BBBBBBBB-..." so A is kept. C is 60 s newer.
        // Rank after A: B (t0), then C (t0 + 60).
        let specs: [(UUID, String, Date)] = [
            (Self.idC, "C", Self.t0.addingTimeInterval(60)),
            (Self.idB, "B", Self.t0),
            (Self.idA, "A", Self.t0),
        ]
        var byName: [String: Bowler] = [:]
        for index in order {
            let (id, name, createdAt) = specs[index]
            byName[name] = insertOwner(id, name: name, createdAt: createdAt)
        }
        let a = byName["A"]!, b = byName["B"]!, c = byName["C"]!
        // A lacks statsProfile and statsScope. B and C both have a profile; B ranks before
        // C, so B's "competitive" wins over C's "league". Only C has a scope.
        b.statsProfile = Bowler.StatsProfile.competitive.rawValue
        c.statsProfile = Bowler.StatsProfile.league.rawValue
        c.statsScope = "all"
        let s1 = insertSession(daysAfterT0: 1)
        let s2 = insertSession(daysAfterT0: 2)
        let s3 = insertSession(daysAfterT0: 3)
        insertGame(for: a, in: s1, gameIndex: 1)
        insertGame(for: b, in: s2, gameIndex: 1)
        insertGame(for: b, in: s2, gameIndex: 2)
        insertGame(for: c, in: s3, gameIndex: 1)
        try context.save()

        try store.mergeOwners()

        let remaining = try owners()
        #expect(remaining.map(\.id) == [Self.idA])
        #expect(try context.fetchCount(FetchDescriptor<Bowler>()) == 1)
        let kept = try #require(remaining.first)
        #expect(kept.name == "A")
        #expect(kept.statsProfile == "competitive")
        #expect(kept.statsScope == "all")
        // Games: 1 (A) + 2 (B) + 1 (C) = 4, all on A, indices unchanged since no session
        // held two owners.
        let all = try games()
        #expect(all.count == 4)
        #expect(all.allSatisfy { $0.bowler?.id == Self.idA })
        #expect(all.filter { $0.session === s2 }.map(\.gameIndex).sorted() == [1, 2])
        #expect(all.first { $0.session === s3 }?.gameIndex == 1)
    }

    // MARK: Two owners in one session

    @Test func movedGamesInASharedSessionKeepFreeIndicesAndAppendClashes() throws {
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        let middle = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(30))
        let newest = insertOwner(Self.idC, name: "S.", createdAt: Self.t0.addingTimeInterval(60))
        let session = insertSession(daysAfterT0: 1)
        insertGame(for: older, in: session, gameIndex: 1, lineupIndex: 2)
        insertGame(for: older, in: session, gameIndex: 2, lineupIndex: 2)
        let c5 = insertGame(for: newest, in: session, gameIndex: 5, lineupIndex: 3)
        let c1 = insertGame(for: newest, in: session, gameIndex: 1, lineupIndex: 3)
        let b3 = insertGame(for: middle, in: session, gameIndex: 3, lineupIndex: 1)
        let b2 = insertGame(for: middle, in: session, gameIndex: 2, lineupIndex: 1)
        try context.save()

        try store.mergeOwners()

        // A holds {1, 2}. Moved games in owner rank (B before C), then gameIndex:
        // B2 clashes, B3 is free and stays 3, C1 clashes, C5 is free and stays 5.
        // Taken is now {1, 2, 3, 5}; clashes append in the same order after the max 5:
        // B2 -> 5 + 1 = 6, C1 -> 5 + 2 = 7.
        #expect(b3.gameIndex == 3)
        #expect(c5.gameIndex == 5)
        #expect(b2.gameIndex == 6)
        #expect(c1.gameIndex == 7)
        // Every game of one bowler in a session carries the same lineupIndex: A's 2.
        #expect([b2, b3, c1, c5].map(\.lineupIndex) == [2, 2, 2, 2])
        #expect(try games().map(\.gameIndex).sorted() == [1, 2, 3, 5, 6, 7])
    }

    @Test func aSessionOnlyAMovedOwnerBowledKeepsItsIndices() throws {
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        let newer = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        let session = insertSession(daysAfterT0: 1)
        let b2 = insertGame(for: newer, in: session, gameIndex: 2, lineupIndex: 3)
        let b4 = insertGame(for: newer, in: session, gameIndex: 4, lineupIndex: 3)
        _ = older
        try context.save()

        try store.mergeOwners()

        // A has no game in the session, so nothing clashes and B's positions stay.
        #expect([b2, b4].map(\.gameIndex) == [2, 4])
        #expect([b2, b4].map(\.lineupIndex) == [3, 3])
    }

    @Test func movedGamesTakeTheKeptOwnersBowlerID() throws {
        insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        let newer = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        let moved = insertGame(for: newer, in: insertSession(daysAfterT0: 1), gameIndex: 1)
        try context.save()
        #expect(moved.bowlerID == Self.idB)

        try store.mergeOwners()

        #expect(moved.bowlerID == Self.idA)
    }

    // MARK: Games without a bowler

    /// Phase 2 sync can deliver a game whose bowler was deleted on another device.
    @Test func gamesWithoutABowlerMoveToTheKeptOwner() throws {
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        let session = insertSession(daysAfterT0: 1)
        let orphan = Game(gameIndex: 1)
        context.insert(orphan)
        orphan.session = session
        orphan.updatedAt = Self.t0
        try context.save()

        try store.mergeOwners()

        #expect(orphan.bowler === older)
        #expect(orphan.bowlerID == Self.idA)
        #expect(orphan.gameIndex == 1)
        #expect(orphan.updatedAt > Self.t0)
    }

    @Test func gamesWithoutABowlerMoveToTheOnlyOwner() throws {
        let owner = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        let orphan = Game(gameIndex: 1)
        context.insert(orphan)
        orphan.session = insertSession(daysAfterT0: 1)
        try context.save()

        try store.mergeOwners()

        #expect(orphan.bowler === owner)
        // Bowlers: the one owner, unchanged.
        #expect(try owners().map(\.id) == [Self.idA])
        #expect(owner.updatedAt == Self.t0)
    }

    // MARK: Idempotence and no-ops

    @Test func runningTheMergeAgainChangesNothing() throws {
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        let newer = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        newer.statsProfile = Bowler.StatsProfile.league.rawValue
        let session = insertSession(daysAfterT0: 1)
        insertGame(for: older, in: session, gameIndex: 1)
        insertGame(for: newer, in: session, gameIndex: 1, lineupIndex: 2)
        try context.save()

        try store.mergeOwners()
        let updatedAt = older.updatedAt
        let indices = try games().map { [$0.gameIndex, $0.lineupIndex] }.sorted { $0.lexicographicallyPrecedes($1) }

        try store.mergeOwners()

        #expect(!context.hasChanges)
        #expect(older.updatedAt == updatedAt)
        #expect(older.statsProfile == "league")
        #expect(try games().map { [$0.gameIndex, $0.lineupIndex] }.sorted { $0.lexicographicallyPrecedes($1) } == indices)
        // [gameIndex, lineupIndex]: A's [1, 1] and the moved game [1 + 1, 1] = [2, 1].
        #expect(indices == [[1, 1], [2, 1]])
    }

    @Test func theKeptOwnersUpdatedAtStaysWhenNothingIsCopied() throws {
        // Both owners keep the defaults (handedness, statsProfile "unknown"; layouts,
        // scope ""; email nil) and the kept owner has a name, so nothing is copied.
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        try context.save()

        try store.mergeOwners()

        #expect(older.updatedAt == Self.t0)
    }

    @Test func anEmptyNameIsFilled() throws {
        let older = insertOwner(Self.idA, name: "", createdAt: Self.t0)
        insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        try context.save()

        try store.mergeOwners()

        #expect(older.name == "Samuel")
        // A field was copied, so updatedAt moves from t0 to the merge time.
        #expect(older.updatedAt > Self.t0)
    }

    @Test func movedGamesGetANewUpdatedAt() throws {
        let older = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        let newer = insertOwner(Self.idB, name: "Samuel", createdAt: Self.t0.addingTimeInterval(60))
        let session = insertSession(daysAfterT0: 1)
        let kept = insertGame(for: older, in: session, gameIndex: 1)
        let moved = insertGame(for: newer, in: session, gameIndex: 2)
        kept.updatedAt = Self.t0
        moved.updatedAt = Self.t0
        try context.save()

        try store.mergeOwners()

        #expect(moved.updatedAt > Self.t0)
        // The kept owner's own game does not move, so it keeps t0.
        #expect(kept.updatedAt == Self.t0)
    }

    @Test func oneOwnerIsLeftUntouched() throws {
        let owner = insertOwner(Self.idA, name: "Sam", createdAt: Self.t0)
        try context.save()

        try store.mergeOwners()

        #expect(!context.hasChanges)
        #expect(owner.updatedAt == Self.t0)
        #expect(try owners().map(\.id) == [Self.idA])
    }

    @Test func noOwnerIsANoOp() throws {
        try store.mergeOwners()
        #expect(try context.fetchCount(FetchDescriptor<Bowler>()) == 0)
    }

    @Test func theMergedOwnerIsTheOneOwnerReturnedBeforeTheMerge() throws {
        insertOwner(Self.idB, name: "B", createdAt: Self.t0)
        insertOwner(Self.idA, name: "A", createdAt: Self.t0)
        try context.save()
        let before = store.bowlers.owner()?.id

        try store.mergeOwners()

        #expect(before == Self.idA)
        #expect(store.bowlers.owner()?.id == before)
    }
}
