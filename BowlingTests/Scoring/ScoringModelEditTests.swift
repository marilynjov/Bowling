import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct ScoringModelEditTests {
    let app: AppModel
    let clock = TestClock()
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
        try ScoringModel(target: try target(mode, ball: ball), app: app, now: clock.tick)
    }

    func strikes(_ model: ScoringModel, _ count: Int) {
        for _ in 0..<count { model.strike() }
    }

    @Test func editPrefillsTheDeck() throws {
        let model = try start(.pinByPin)
        model.setShown(PinSet(pins: [7, 10]))
        model.next()
        model.spare()
        model.beginEdit(frame: 1)
        #expect(model.edit == FrameEdit(frameIndex: 1, rollIndex: 1))
        #expect(model.pad?.shown == PinSet(pins: [7, 10]))
    }

    @Test func replacingBall1MovesToBall2() throws {
        let model = try start(.countOnly)
        model.count(7)
        model.count(1)
        model.strike()
        model.beginEdit(frame: 1)
        #expect(model.editedCount == 7)
        model.count(8)
        #expect(model.edit == FrameEdit(frameIndex: 1, rollIndex: 2))
        #expect(model.editedCount == 1)
        #expect(model.scorecard.frames[0].marks == [.count(8), .count(1)])
        #expect(model.clearedFrames.isEmpty)
    }

    @Test func strikeChangedTo7EndsTheEditAndAsksForBall2() throws {
        let model = try start(.countOnly)
        model.count(10)
        model.count(3)
        model.count(4)
        model.beginEdit(frame: 1)
        model.count(7)
        #expect(model.edit == nil)
        #expect(model.pad?.position.frameIndex == 1)
        #expect(model.pad?.position.rollIndex == 2)
        #expect(model.clearedFrames == [2])
    }

    @Test func clearedTextWording() {
        #expect(FrameEdit.clearedText([4]) == "Frame 4 was cleared. Enter it again.")
        #expect(FrameEdit.clearedText([4, 5]) == "Frames 4 and 5 were cleared. Enter them again.")
        #expect(FrameEdit.clearedText([4, 5, 6]) == "Frames 4, 5 and 6 were cleared. Enter them again.")
        #expect(FrameEdit.clearedText([]) == nil)
    }

    @Test func cancelKeepsReplacedBalls() throws {
        let model = try start(.countOnly)
        model.count(7)
        model.count(1)
        model.beginEdit(frame: 1)
        model.count(8)
        model.cancelEdit()
        #expect(model.edit == nil)
        #expect(model.scorecard.frames[0].marks == [.count(8), .count(1)])
    }

    @Test func editingACompleteGameCanReopenIt() throws {
        let model = try start(.pinByPin)
        strikes(model, 12)
        #expect(model.isComplete)
        model.beginEdit(frame: 10)
        model.setShown(PinSet(pins: [7]))
        model.next()
        #expect(model.edit == nil)
        #expect(!model.isComplete)
        #expect(model.pad?.position.frameIndex == 10)
        #expect(model.pad?.position.rollIndex == 2)
    }

    @Test func editKeepsTheRollsBall() throws {
        let model = try start(.pinByPin, ball: ballA.id)
        model.pickBall(ballB.id)
        model.strike()
        model.beginEdit(frame: 1)
        #expect(model.rollBallID == ballB.id)
    }

    @Test func editingADefaultBallRollStoresNoOverride() throws {
        let model = try start(.pinByPin, ball: ballA.id)
        model.strike()
        model.beginEdit(frame: 1)
        #expect(model.rollBallID == ballA.id)
        model.strike()
        #expect(model.game.frames[0].rolls[0].ballID == nil)
    }

    @Test func aRefusedReplaceKeepsTheEdit() throws {
        let model = try start(.countOnly)
        model.count(7)
        model.count(2)
        model.beginEdit(frame: 1)
        model.count(8)
        #expect(model.edit == FrameEdit(frameIndex: 1, rollIndex: 2))
        model.count(5)
        #expect(app.error != nil)
        #expect(model.edit == FrameEdit(frameIndex: 1, rollIndex: 2))
    }

    @Test func editingAFillBallKeepsTheGameComplete() throws {
        let model = try start(.pinByPin)
        strikes(model, 12)
        model.beginEdit(frame: 10)
        model.strike()
        model.strike()
        #expect(model.edit == FrameEdit(frameIndex: 10, rollIndex: 3))
        model.setShown(PinSet(pins: [10]))
        model.next()
        #expect(model.edit == nil)
        #expect(model.isComplete)
        #expect(model.scorecard.finalScore == 299)
    }

    @Test func clearRollsEndsTheEdit() throws {
        let model = try start(.pinByPin)
        model.strike()
        model.beginEdit(frame: 1)
        model.clearRolls()
        #expect(model.edit == nil)
        #expect(model.pad?.position.frameIndex == 1)
    }

    @Test func undoDoesNothingWhileEditing() throws {
        let model = try start(.pinByPin)
        strikes(model, 2)
        model.beginEdit(frame: 1)
        model.undo()
        #expect(model.scorecard.frames[1].marks == [.strike])
    }

    @Test func writesReportTheirKind() throws {
        let model = try start(.pinByPin)
        var kinds: [ScoringWrite] = []
        model.onWrite = { kinds.append($0) }
        model.strike()
        model.beginEdit(frame: 1)
        model.strike()
        model.undo()
        #expect(kinds == [.roll, .edit, .other])
    }

    @Test func currentScoreIsTheLastRunningTotal() throws {
        let model = try start(.countOnly)
        model.count(7)
        model.count(2)
        model.count(10)
        #expect(model.currentScore == 9)
        let typed = try start(.finalOnly)
        #expect(typed.currentScore == 0)
        typed.saveFinalScore("187")
        #expect(typed.currentScore == 187)
    }

    @Test func replacingARollKeepsThePickedOverride() throws {
        let model = try start(.pinByPin, ball: ballA.id)
        model.strike()
        model.beginEdit(frame: 1)
        model.pickBall(ballB.id)
        model.strike()
        #expect(model.game.frames[0].rolls[0].ballID == ballB.id)
    }
}
