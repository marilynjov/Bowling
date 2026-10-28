import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct GameSummaryTests {
    let store: BowlingStore
    let sam: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        sam = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
    }

    /// Sam's session, with `rolls` (or `score`) in game 1 and then `game2` in game 2.
    func bowler(
        _ mode: EntryMode, rolls: [RollInput] = [], score: Int? = nil, game2: [RollInput]? = nil
    ) throws -> SessionBowler {
        let session = try store.sessions.startSession(
            SessionMetadata(date: .now, eventType: .practice), bowlers: [(sam.id, nil)], entryMode: mode
        )
        let game = try #require(try store.sessions.session(session).bowlers.first?.games.first)
        for roll in rolls { _ = try store.games.recordRoll(roll, ballID: nil, in: game.id) }
        if let score { try store.games.setFinalScore(score, for: game.id) }
        if let game2 {
            let next = try #require(try store.games.startNextGame(in: session).first)
            for roll in game2 { _ = try store.games.recordRoll(roll, ballID: nil, in: next) }
        }
        return try #require(try store.sessions.session(session).bowlers.first)
    }

    let perfect = [RollInput](repeating: .pinsLeft([]), count: 12)
    let nines = [RollInput]((0..<10).flatMap { _ in [RollInput.count(9), .count(0)] })

    @Test func perfectGame() throws {
        let summary = try #require(GameSummary(try bowler(.pinByPin, rolls: perfect), gameIndex: 1))
        #expect(summary.name == "Sam")
        #expect(summary.score == 300)
        #expect(summary.counts == GameSummary.Counts(strikes: 12, spares: 0, opens: 0))
        #expect(summary.leaves == .none)
        #expect(summary.series == nil)
        #expect(summary.seriesText == nil)
        #expect(summary.countsText == "12 strikes · 0 spares · 0 open")
    }

    @Test func openFramesWithLeaves() throws {
        let ten = RollInput.pinsLeft(PinSet(pins: [10]))
        let rolls: [RollInput] = [.pinsLeft(PinSet(pins: [7, 10])), .pinsLeft([]), .pinsLeft(PinSet(pins: [4])), .pinsLeft(PinSet(pins: [4]))]
            + (3...10).flatMap { _ in [ten, ten] }
        let summary = try #require(GameSummary(try bowler(.pinByPin, rolls: rolls), gameIndex: 1))
        #expect(summary.counts?.spares == 1)
        #expect(summary.counts?.opens == 9)
        #expect(summary.countsText == "0 strikes · 1 spare · 9 open")
        guard case .diagrams(let leaves) = summary.leaves else {
            Issue.record("expected diagrams, got \(summary.leaves)")
            return
        }
        #expect(leaves.count == 10)
        #expect(leaves.prefix(2).map(\.pins) == [PinSet(pins: [7, 10]), PinSet(pins: [4])])
    }

    @Test func countGameAsksForPins() throws {
        let summary = try #require(GameSummary(try bowler(.countOnly, rolls: nines), gameIndex: 1))
        #expect(summary.score == 90)
        #expect(summary.leaves == .enterPins)
        #expect(summary.counts == GameSummary.Counts(strikes: 0, spares: 0, opens: 10))
    }

    @Test func finalScoreGame() throws {
        let summary = try #require(GameSummary(try bowler(.finalOnly, score: 187), gameIndex: 1))
        #expect(summary.score == 187)
        #expect(summary.counts == nil)
        #expect(summary.countsText == nil)
        #expect(summary.leaves == .hidden)
    }

    @Test func seriesFromGame2() throws {
        let strikes = [RollInput](repeating: .count(10), count: 12)
        let bowler = try bowler(.countOnly, rolls: strikes, game2: nines)
        let summary = try #require(GameSummary(bowler, gameIndex: 2))
        #expect(summary.series == 390)
        #expect(summary.seriesText == "Series 390")
        #expect(GameSummary(bowler, gameIndex: 3) == nil)
    }
}
