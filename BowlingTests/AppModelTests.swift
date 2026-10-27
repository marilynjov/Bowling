import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct AppModelTests {
    let app: AppModel

    init() throws {
        app = AppModel(store: try BowlingStore(inMemory: true))
    }

    private func createOwner() throws -> BowlerRecord {
        try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
    }

    @Test func writeBumpsRevision() throws {
        #expect(app.revision == 0)
        let owner = try createOwner()
        #expect(owner.name == "Sam")
        #expect(app.revision == 1)
    }

    @Test func throwingWriteBumpsRevisionAndRethrows() {
        #expect(throws: RepositoryError.notFound) {
            try app.write { try $0.bowlers.updateOwner(name: "A", handedness: .right) }
        }
        #expect(app.revision == 1)
    }

    @Test func needsOnboardingUntilOwnerExists() throws {
        #expect(app.needsOnboarding)
        _ = try createOwner()
        #expect(!app.needsOnboarding)
    }

    @Test func needsOnboardingAfterDeleteAllData() throws {
        _ = try createOwner()
        #expect(!app.needsOnboarding)
        try app.write { try $0.deleteAllData() }
        #expect(app.needsOnboarding)
    }

    @Test func previewHasTheDemoOwner() {
        #expect(!AppModel.preview().needsOnboarding)
    }

    @Test func openSessionSelectsHistoryAndPushesTheSession() {
        let a = SessionID(), b = SessionID()
        app.historyPath = [.session(a), .game(GameID())]
        app.openSession(b)
        #expect(app.selectedTab == .history)
        #expect(app.historyPath == [.session(b)])
    }

    @Test func popHistoryRemovesTheRouteAndAbove() {
        let a = SessionID(), g = GameID()
        app.historyPath = [.session(a), .game(g)]
        app.popHistory(from: .session(a))
        #expect(app.historyPath.isEmpty)
        app.historyPath = [.session(a), .game(g)]
        app.popHistory(from: .game(g))
        #expect(app.historyPath == [.session(a)])
        app.popHistory(from: .session(SessionID()))
        #expect(app.historyPath == [.session(a)])
    }

    @Test func closingScoringFromHistoryKeepsTheSession() throws {
        let owner = try createOwner()
        let id = try app.write {
            try $0.sessions.startSession(
                SessionMetadata(date: .now, eventType: .league),
                bowlers: [(bowlerID: owner.id, defaultBallID: nil)], entryMode: .countOnly
            )
        }
        let gameID = try #require(app.store.sessions.session(id).bowlers.first?.games.first?.id)
        app.scoring = ScoringTarget(sessionID: id, gameID: gameID, startsOnTarget: true)
        app.closeScoring()
        #expect(app.scoring == nil)
        _ = try app.store.sessions.session(id)
    }
}

/// The shared alert must come from the topmost view: iOS can't present an alert from a
/// view that is already presenting the Scoring cover.
@Suite struct ErrorPresenterTests {
    let app: AppModel

    init() throws {
        app = AppModel(store: try BowlingStore(inMemory: true))
    }

    struct Boom: Error {}

    @Test func noErrorShowsNowhere() {
        #expect(!app.showsError(in: .root))
        #expect(!app.showsError(in: .scoring))
    }

    @Test func errorWithScoringClosedShowsAtTheRoot() {
        app.error = Boom()
        #expect(app.showsError(in: .root))
        #expect(!app.showsError(in: .scoring))
    }

    @Test func errorWhileScoringShowsOnTheCover() {
        app.scoring = ScoringTarget(sessionID: SessionID(), gameID: GameID())
        app.error = Boom()
        #expect(!app.showsError(in: .root))
        #expect(app.showsError(in: .scoring))
    }

    @Test func newSessionSheetShowsTheAlertWhileUp() {
        app.error = Boom()
        app.isStartingSession = true
        #expect(app.showsError(in: .newSession))
        #expect(!app.showsError(in: .root))
        #expect(!app.showsError(in: .scoring))
        app.scoring = ScoringTarget(sessionID: SessionID(), gameID: GameID())
        #expect(app.showsError(in: .scoring))
        #expect(!app.showsError(in: .newSession))
    }

    @Test func sessionDetailsShowsErrorsWhileEditing() {
        app.editingSessionDetails = SessionID()
        app.error = Boom()
        #expect(app.showsError(in: .sessionDetails))
        #expect(!app.showsError(in: .root))
    }

    @Test func quickScoreSheetShowsTheAlertWhileUp() {
        app.error = Boom()
        app.isQuickScoring = true
        #expect(app.showsError(in: .quickScore))
        #expect(!app.showsError(in: .root))
        app.isStartingSession = true
        #expect(app.showsError(in: .newSession))
        #expect(!app.showsError(in: .quickScore))
    }
}
