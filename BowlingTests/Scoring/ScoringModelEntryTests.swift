import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct ScoringModelEntryTests {
    let app: AppModel
    let sam: BowlerRecord

    init() throws {
        let suite = UserDefaults(suiteName: "test.\(UUID())")!
        app = AppModel(
            store: try BowlingStore(inMemory: true),
            sessionDefaults: SessionDefaultsStore(suite),
            scoringSettings: ScoringSettings(suite)
        )
        sam = try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
    }

    func start(_ mode: EntryMode) throws -> ScoringModel {
        let target = try app.write { store in
            let session = try store.sessions.startSession(
                SessionMetadata(date: .now, eventType: .practice), bowlers: [(sam.id, nil)], entryMode: mode
            )
            let game = try #require(try store.sessions.session(session).bowlers.first?.games.first)
            return ScoringTarget(sessionID: session, gameID: game.id)
        }
        return try ScoringModel(target: target, app: app)
    }

    @Test func modeChangesBeforeTheFirstRoll() throws {
        let model = try start(.pinByPin)
        #expect(model.canChangeEntryMode)
        model.setEntryMode(.countOnly)
        #expect(model.game.entryMode == .countOnly)
        #expect(model.pad?.entryMode == .countOnly)
    }

    @Test func modeIsLockedAfterARoll() throws {
        let model = try start(.pinByPin)
        model.strike()
        #expect(!model.canChangeEntryMode)
        model.setEntryMode(.countOnly)
        #expect(app.error as? RepositoryError == .entryModeLocked)
        #expect(model.game.entryMode == .pinByPin)
    }

    @Test func clearRollsUnlocksTheMode() throws {
        let model = try start(.pinByPin)
        model.strike()
        model.clearRolls()
        #expect(!model.canUndo)
        #expect(model.canChangeEntryMode)
        model.setEntryMode(.countOnly)
        #expect(model.game.entryMode == .countOnly)
        #expect(app.error == nil)
    }

    @Test func finalScoreCompletesTheGame() throws {
        let model = try start(.finalOnly)
        #expect(!model.isComplete)
        #expect(model.pad == nil)
        model.saveFinalScore("187")
        #expect(model.isComplete)
        #expect(model.scorecard.finalScore == 187)
        #expect(!model.isEditingFinalScore)
    }

    @Test func badFinalScoreIsIgnored() throws {
        let model = try start(.finalOnly)
        let before = app.revision
        model.saveFinalScore("301")
        #expect(!model.isComplete)
        #expect(app.revision == before)
    }

    @Test func changeScoreReplacesIt() throws {
        let model = try start(.finalOnly)
        model.saveFinalScore("187")
        model.isEditingFinalScore = true
        model.saveFinalScore("192")
        #expect(model.scorecard.finalScore == 192)
        #expect(!model.isEditingFinalScore)
    }

    @Test func switchingATypedScoreToPinsResetsIt() throws {
        let model = try start(.finalOnly)
        #expect(!model.discardsTypedScore)
        model.saveFinalScore("187")
        #expect(model.discardsTypedScore)
        model.setEntryMode(.pinByPin)
        #expect(!model.isComplete)
        #expect(model.pad?.position.frameIndex == 1)
        #expect(model.game.finalScore == 0)
    }
}
