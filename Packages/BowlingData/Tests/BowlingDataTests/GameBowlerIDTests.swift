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
