import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

/// `Game.bowlerID` copies `bowler.id` wherever a game gets a bowler, so it survives the
/// bowler being deleted or arriving later through sync (#89).
@MainActor @Suite struct GameBowlerIDTests {
    let store: BowlingStore
    var context: ModelContext { store.context }

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    private func games() throws -> [Game] {
        try context.fetch(FetchDescriptor<Game>())
    }

    private func expectEveryGameMatchesItsBowler() throws {
        let all = try games()
        #expect(!all.isEmpty)
        for game in all {
            #expect(game.bowler != nil)
            #expect(game.bowlerID == game.bowler?.id)
        }
    }

    @Test func assignSetsAndClearsTheID() {
        let bowler = Bowler(name: "Sam")
        let game = Game(gameIndex: 1)
        context.insert(bowler)
        context.insert(game)

        game.assign(bowler)
        #expect(game.bowlerID == bowler.id)

        let other = Bowler(name: "Alex")
        context.insert(other)
        game.assign(other)
        #expect(game.bowlerID == other.id)

        game.assign(nil)
        #expect(game.bowlerID == nil)
    }

    @Test func startSessionAndNextGameSetTheID() throws {
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let partner = try store.bowlers.createBowler(name: "Alex")
        let session = try store.sessions.startSession(
            SessionMetadata(date: DemoFixture.referenceDate, eventType: .practice),
            bowlers: [(owner.id, nil), (partner.id, nil)], entryMode: .pinByPin
        )
        _ = try store.games.startNextGame(in: session)

        #expect(try games().count == 4)
        try expectEveryGameMatchesItsBowler()
    }

    @Test func quickScoreSetsTheID() throws {
        _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        _ = try store.sessions.quickScore(finalScore: 180, now: DemoFixture.referenceDate)

        try expectEveryGameMatchesItsBowler()
    }

    @Test func demoFixturesSetTheID() throws {
        let demo = try BowlingStore.demo(now: DemoFixture.referenceDate)
        let all = try demo.context.fetch(FetchDescriptor<Game>())
        #expect(!all.isEmpty)
        for game in all {
            #expect(game.bowlerID == game.bowler?.id)
            #expect(game.recordedRollCount == (game.frames ?? []).reduce(0) { $0 + ($1.rolls?.count ?? 0) })
        }
    }
}

/// #110: a game whose Bowler row is gone, deleted on another device or not imported yet,
/// still reads as that bowler's in its record, stats, and CSV export.
@MainActor @Suite struct MissingBowlerReaderTests {
    let store: BowlingStore
    var context: ModelContext { store.context }
    let friendID: UUID
    let game: Game

    init() throws {
        store = try BowlingStore(inMemory: true)
        _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
        let friend = try store.bowlers.createBowler(name: "Alex")
        let session = try store.sessions.startSession(
            SessionMetadata(date: DemoFixture.referenceDate, eventType: .league),
            bowlers: [(friend.id, nil)], entryMode: .finalOnly
        )
        let id = try #require(try store.sessions.session(session).bowlers.first?.games.first?.id)
        try store.games.setFinalScore(200, for: id)
        game = try store.context.game(id)
        let row = try store.context.bowler(friend.id)
        friendID = friend.id
        store.context.delete(row)
        try store.context.save()
    }

    @Test func theRecordKeepsTheBowlerID() throws {
        #expect(game.bowler == nil)
        #expect(try store.games.game(game.id).bowlerID == friendID)
    }

    @Test func statsCountTheGameForItsBowlerOnly() throws {
        let owner = try #require(context.owner())
        let calendar = Calendar(identifier: .gregorian)
        let friends = store.stats.games(matching: StatsFilter(bowlerID: friendID), now: .now, calendar: calendar)
        let owners = store.stats.games(matching: StatsFilter(bowlerID: owner.id), now: .now, calendar: calendar)
        #expect(friends.map(\.id) == [game.id])
        #expect(owners.isEmpty)
        #expect(store.stats.defaultEventTypes(for: friendID, preferCompetition: true) == BowlingCore.EventType.competition)
    }

    @Test func csvExportKeepsTheBowlerID() throws {
        let games = try #require(try store.csvTables().first { $0.fileName == "games.csv" })
        #expect(try games.rows.map { try games.value($0, "bowlerID") } == [friendID.uuidString])
    }
}
