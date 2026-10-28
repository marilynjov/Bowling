import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct SessionScoringModelTests {
    let suite = UserDefaults(suiteName: "test.\(UUID())")!
    let app: AppModel
    let clock = TestClock()
    let sam: BowlerRecord
    let alex: BowlerRecord
    let ballA: BallSummary

    init() throws {
        app = AppModel(
            store: try BowlingStore(inMemory: true),
            sessionDefaults: SessionDefaultsStore(suite),
            scoringSettings: ScoringSettings(suite)
        )
        sam = try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
        alex = try app.write { try $0.bowlers.createBowler(name: "Alex") }
        ballA = try app.write { try $0.balls.addBall(name: "Phaze", weightPounds: 15, intendedRole: .strike, brand: "Storm") }
    }

    /// A session for `lineup` (Sam and Alex by default), every bowler with `ballA`; returns
    /// Sam's game 1.
    func target(_ mode: EntryMode, lineup: [BowlerRecord]? = nil) throws -> ScoringTarget {
        let lineup = lineup ?? [sam, alex]
        return try app.write { store in
            let session = try store.sessions.startSession(
                SessionMetadata(date: .now, eventType: .league),
                bowlers: lineup.map { ($0.id, ballA.id) }, entryMode: mode
            )
            let game = try #require(try store.sessions.session(session).bowlers.first?.games.first)
            return ScoringTarget(sessionID: session, gameID: game.id)
        }
    }

    func open(_ target: ScoringTarget) throws -> SessionScoringModel {
        try SessionScoringModel(target: target, app: app, now: clock.tick)
    }

    func start(_ mode: EntryMode, lineup: [BowlerRecord]? = nil) throws -> SessionScoringModel {
        try open(try target(mode, lineup: lineup))
    }

    /// Both bowlers' final-only games saved, so the summary is up.
    func finishedTypedNight() throws -> SessionScoringModel {
        let model = try start(.finalOnly)
        model.current.saveFinalScore("180")
        model.current.saveFinalScore("150")
        return model
    }

    @Test func opensOnTheRulesBowler() throws {
        let target = try target(.countOnly)
        try app.write { store in
            _ = try store.games.recordRoll(.count(7), ballID: nil, in: target.gameID)
            _ = try store.games.recordRoll(.count(2), ballID: nil, in: target.gameID)
        }
        #expect(try open(target).current.bowlerName == "Alex")
    }

    @Test func opensOnTheTargetWithRotationOff() throws {
        app.scoringSettings.rotateBowlers = false
        let target = try target(.countOnly)
        try app.write { store in
            _ = try store.games.recordRoll(.count(7), ballID: nil, in: target.gameID)
            _ = try store.games.recordRoll(.count(2), ballID: nil, in: target.gameID)
        }
        #expect(try open(target).current.bowlerName == "Sam")
    }

    @Test func aFrameEndingSwitchesBowler() throws {
        let model = try start(.countOnly)
        #expect(model.current.bowlerName == "Sam")
        model.current.count(7)
        #expect(model.current.bowlerName == "Sam")
        model.current.count(2)
        #expect(model.current.bowlerName == "Alex")
        #expect(model.title == "Game 1 · Alex")
    }

    @Test func undoDoesNotSwitch() throws {
        let model = try start(.pinByPin)
        model.current.strike()
        #expect(model.currentIndex == 1)
        model.select(0)
        model.current.undo()
        #expect(model.currentIndex == 0)
    }

    @Test func tappingAChipSwitches() throws {
        let model = try start(.pinByPin)
        model.select(1)
        #expect(model.current.bowlerName == "Alex")
        model.current.strike()
        #expect(model.currentIndex == 0)
    }

    @Test func lastGameCompletingShowsTheSummary() throws {
        let model = try start(.finalOnly)
        model.current.saveFinalScore("180")
        #expect(model.current.bowlerName == "Alex")
        #expect(!model.isShowingSummary)
        model.current.saveFinalScore("150")
        #expect(model.isShowingSummary)
        #expect(app.isShowingGameSummary)
        #expect(model.summaries.map(\.score) == [180, 150])
    }

    @Test func oneBowlerShowsTheSummary() throws {
        let model = try start(.finalOnly, lineup: [sam])
        model.current.saveFinalScore("200")
        #expect(model.isShowingSummary)
    }

    @Test func nextGameStartsGame2ForBoth() throws {
        let model = try finishedTypedNight()
        model.nextGame()
        #expect(model.gameIndex == 2)
        #expect(model.bowlers.count == 2)
        #expect(model.bowlers.allSatisfy { $0.game.defaultBallID == ballA.id && $0.game.gameIndex == 2 })
        #expect(model.currentIndex == 0)
        #expect(!model.isShowingSummary)
        #expect(!app.isShowingGameSummary)
    }

    @Test func nextGameTwiceMakesOneGame() throws {
        let model = try finishedTypedNight()
        model.nextGame()
        model.nextGame()
        #expect(model.gameIndex == 2)
        let detail = try app.store.sessions.session(model.sessionID)
        #expect(detail.bowlers.map(\.games.count) == [2, 2])
    }

    @Test func openingACompleteGameShowsNoSummary() throws {
        let target = try target(.finalOnly)
        try app.write { store in
            for bowler in try store.sessions.session(target.sessionID).bowlers {
                try store.games.setFinalScore(170, for: bowler.games[0].id)
            }
        }
        let model = try open(target)
        #expect(model.allFinished)
        #expect(!model.isShowingSummary)
    }

    @Test func undoThenFinishShowsTheSummaryAgain() throws {
        let model = try start(.pinByPin, lineup: [sam])
        for _ in 0..<12 { model.current.strike() }
        #expect(model.isShowingSummary)
        model.isShowingSummary = false
        model.current.undo()
        model.current.strike()
        #expect(model.isShowingSummary)
    }

    @Test func closingResetsTheSummaryPresenter() throws {
        let target = try target(.finalOnly, lineup: [sam])
        let model = try open(target)
        app.scoring = target
        model.current.saveFinalScore("200")
        #expect(app.isShowingGameSummary)
        app.closeScoring()
        #expect(!app.isShowingGameSummary)
        app.error = RepositoryError.notFound
        #expect(app.showsError(in: .root))
    }

    @Test func aFailedNextGameKeepsTheSheet() throws {
        let target = try target(.finalOnly)
        let model = try open(target)
        app.scoring = target
        model.current.saveFinalScore("180")
        model.current.saveFinalScore("150")
        try app.write { try $0.sessions.deleteSession(target.sessionID) }
        model.nextGame()
        #expect(app.error != nil)
        #expect(model.isShowingSummary)
        #expect(app.showsError(in: .gameSummary))
    }
}
