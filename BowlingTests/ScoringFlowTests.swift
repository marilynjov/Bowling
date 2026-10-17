import BowlingCore
import BowlingData
import Testing
@testable import Bowling

@Suite struct ScoringFlowTests {
    let app: AppModel
    let owner: BowlerRecord

    init() throws {
        app = AppModel(store: try BowlingStore(inMemory: true))
        owner = try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
    }

    @Test func startOpensScoring() throws {
        try app.startPracticeSession()
        let target = try #require(app.scoring)
        let summary = try #require(app.store.sessions.sessions().first { $0.id == target.sessionID })
        #expect(summary.eventType == .practice)
        let detail = try app.store.sessions.session(target.sessionID)
        #expect(detail.bowlers.map(\.bowler.id) == [owner.id])
        #expect(detail.bowlers.first?.games.first?.id == target.gameID)
        #expect(detail.bowlers.first?.games.first?.gameIndex == 1)
    }

    @Test func startThenCloseLeavesNoSession() throws {
        try app.startPracticeSession()
        app.closeScoring()
        #expect(app.scoring == nil)
        #expect(app.store.sessions.sessions().isEmpty)
        #expect(app.error == nil)
    }
}
