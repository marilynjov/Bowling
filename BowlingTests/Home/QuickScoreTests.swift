import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct QuickScoreTests {
    let app: AppModel
    let owner: BowlerRecord

    init() throws {
        app = AppModel(
            store: try BowlingStore(inMemory: true),
            sessionDefaults: SessionDefaultsStore(UserDefaults(suiteName: "test.\(UUID())")!)
        )
        owner = try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
        app.isQuickScoring = true
    }

    @Test func quickScoreSavesACasualFinalOnlyGame() throws {
        try app.quickScore(187)
        #expect(!app.isQuickScoring)
        let saved = try #require(app.savedQuickScore)
        #expect(saved.score == 187)
        let detail = try app.store.sessions.session(saved.sessionID)
        #expect(detail.metadata.eventType == .casual)
        #expect(Calendar.current.isDateInToday(detail.metadata.date))
        let games = try #require(detail.bowlers.first { $0.bowler.id == owner.id }).games
        #expect(games.count == 1)
        #expect(games.first?.isComplete == true)
        #expect(games.first?.entryMode == .finalOnly)
        #expect(games.first?.finalScore == 187)
    }

    @Test func failedQuickScoreKeepsTheSheet() {
        #expect(throws: (any Error).self) { try app.quickScore(301) }
        #expect(app.isQuickScoring)
        #expect(app.savedQuickScore == nil)
        #expect(app.store.sessions.sessions().isEmpty)
    }

    @Test func undoRemovesTheSession() throws {
        try app.quickScore(187)
        try app.undoQuickScore()
        #expect(app.store.sessions.sessions().isEmpty)
        #expect(app.savedQuickScore == nil)
    }

    @Test func undoTwiceDeletesOnce() throws {
        let earlier = try app.write { try $0.sessions.quickScore(finalScore: 150, now: .now.addingTimeInterval(-86_400)) }
        try app.quickScore(187)
        try app.undoQuickScore()
        try app.undoQuickScore()
        #expect(app.store.sessions.sessions().map(\.id) == [earlier])
    }

    @Test func secondQuickScoreReplacesTheUndo() throws {
        try app.quickScore(150)
        try app.quickScore(160)
        try app.undoQuickScore()
        let sessions = app.store.sessions.sessions()
        #expect(sessions.count == 1)
        #expect(sessions.first?.games.first?.finalScore == 150)
    }

    @Test func resumeOpensScoring() {
        let target = ScoringTarget(sessionID: SessionID(), gameID: GameID())
        app.resume(target)
        #expect(app.scoring == target)
    }
}
