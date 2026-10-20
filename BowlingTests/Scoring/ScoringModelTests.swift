import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct ScoringModelTests {
    let app: AppModel
    let sam: BowlerRecord
    let ballA: BallSummary
    let ballB: BallSummary

    init() throws {
        let suite = UserDefaults(suiteName: "test.\(UUID())")!
        app = AppModel(
            store: try BowlingStore(inMemory: true),
            sessionDefaults: SessionDefaultsStore(suite),
            scoringSettings: ScoringSettings(suite)
        )
        sam = try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
        ballA = try app.write { try $0.balls.addBall(name: "Phaze", weightPounds: 15, intendedRole: .strike, brand: "Storm") }
        ballB = try app.write { try $0.balls.addBall(name: "Pearl", weightPounds: 15, intendedRole: .spare, brand: "Brunswick") }
    }

    func target(_ mode: EntryMode, ball: BallID? = nil) throws -> ScoringTarget {
        try app.write { store in
            let session = try store.sessions.startSession(
                SessionMetadata(date: .now, eventType: .practice), bowlers: [(sam.id, ball)], entryMode: mode
            )
            let game = try #require(try store.sessions.session(session).bowlers.first?.games.first)
            return ScoringTarget(sessionID: session, gameID: game.id)
        }
    }

    func start(_ mode: EntryMode, ball: BallID? = nil) throws -> ScoringModel {
        try ScoringModel(target: try target(mode, ball: ball), app: app)
    }

    @Test func strikeAdvancesToFrame2() throws {
        let model = try start(.pinByPin)
        let before = app.revision
        model.strike()
        #expect(model.pad?.position.frameIndex == 2)
        #expect(model.scorecard.frames[0].marks == [.strike])
        #expect(app.revision > before)
    }

    @Test func spareFromTheDeck() throws {
        let model = try start(.pinByPin)
        model.setShown(PinSet(pins: [7, 10]))
        model.next()
        model.spare()
        #expect(model.scorecard.frames[0].marks == [.count(8), .spare])
    }

    @Test func firstBallFoulThenTenIsASpare() throws {
        let model = try start(.pinByPin)
        model.foul()
        model.spare()
        #expect(model.scorecard.frames[0].marks == [.foul, .spare])
    }

    @Test func secondBallFoulEndsTheFrame() throws {
        let model = try start(.countOnly)
        model.count(7)
        model.foul()
        #expect(model.pad?.position.frameIndex == 2)
        #expect(model.scorecard.frames[0].runningTotal == 7)
    }

    @Test func undoReopensTheLastRoll() throws {
        let model = try start(.pinByPin)
        model.strike()
        model.undo()
        #expect(model.pad?.position.frameIndex == 1)
        #expect(model.pad?.position.rollIndex == 1)
        #expect(!model.canUndo)
    }

    @Test func undoBeforeFirstRollDoesNothing() throws {
        let model = try start(.pinByPin)
        #expect(!model.canUndo)
        let before = app.revision
        model.undo()
        #expect(app.revision == before)
        #expect(app.error == nil)
    }

    @Test func twelveStrikesIs300() throws {
        let model = try start(.pinByPin)
        for _ in 1...12 { model.strike() }
        #expect(model.isComplete)
        #expect(model.pad == nil)
        #expect(model.scorecard.finalScore == 300)
        model.undo()
        #expect(!model.isComplete)
        #expect(model.pad?.position.frameIndex == 10)
        #expect(model.pad?.position.rollIndex == 3)
    }

    @Test func openTenthEndsTheGame() throws {
        let model = try start(.countOnly)
        for _ in 1...9 { model.count(0); model.count(0) }
        model.count(7)
        model.count(2)
        #expect(model.isComplete)
        #expect(model.scorecard.finalScore == 9)
    }

    @Test func fullCountGame() throws {
        let model = try start(.countOnly)
        for _ in 1...9 { model.count(9); model.count(0) }
        model.count(10)
        model.count(10)
        model.count(10)
        #expect(model.isComplete)
        #expect(model.scorecard.finalScore == 111)
    }

    @Test func pickedBallGoesOnOneRoll() throws {
        let model = try start(.countOnly, ball: ballA.id)
        #expect(model.rollBallID == ballA.id)
        model.pickBall(ballB.id)
        #expect(model.rollBallID == ballB.id)
        model.count(3)
        #expect(model.ballOverride == nil)
        model.count(2)
        #expect(model.game.frames[0].rolls[0].ballID == ballB.id)
        #expect(model.game.frames[0].rolls[1].ballID == ballA.id)
    }

    @Test func pickedNoBallGoesWithoutABall() throws {
        let model = try start(.countOnly, ball: ballA.id)
        model.pickBall(nil)
        #expect(model.rollBallID == nil)
        model.count(3)
        #expect(model.game.frames[0].rolls[0].ballID == nil)
        #expect(model.rollBallID == ballA.id)
    }

    @Test func reopeningResumesAtTheNextRoll() throws {
        let model = try start(.countOnly)
        model.count(4)
        let reopened = try ScoringModel(target: model.target, app: app)
        #expect(reopened.pad?.position.rollIndex == 2)
    }

    @Test func openingACompleteGameShowsComplete() throws {
        let model = try start(.pinByPin)
        for _ in 1...12 { model.strike() }
        let reopened = try ScoringModel(target: model.target, app: app)
        #expect(reopened.isComplete)
        #expect(reopened.canUndo)
    }

    @Test func bowlerNameIsTheGamesBowler() throws {
        #expect(try start(.pinByPin).bowlerName == "Sam")
    }
}
