import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct GameDetailDataTests {
    let store: BowlingStore
    let sam: BowlerRecord
    let phaze: BallSummary
    let hammer: BallSummary

    init() throws {
        store = try BowlingStore(inMemory: true)
        sam = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        phaze = try store.balls.addBall(name: "Phaze", weightPounds: 15, intendedRole: .strike, brand: "Storm")
        hammer = try store.balls.addBall(name: "Hammer", weightPounds: 15, intendedRole: .spare, brand: "Hammer")
    }

    func name(_ id: BallID) -> String? {
        [phaze, hammer].first { $0.id == id }?.name
    }

    /// The first game of a new session, with `ball` as its default.
    func game(_ mode: EntryMode, ball: BallID? = nil) throws -> GameID {
        let session = try store.sessions.startSession(
            SessionMetadata(date: .now, eventType: .practice), bowlers: [(bowlerID: sam.id, defaultBallID: ball)], entryMode: mode
        )
        return try #require(try store.sessions.session(session).bowlers.first?.games.first?.id)
    }

    func load(_ id: GameID) throws -> GameDetailData {
        try GameDetailData.load(id, from: store, ballName: name)
    }

    @Test func pinByPinShowsEachBowledFramesLeave() throws {
        let id = try game(.pinByPin)
        try store.games.recordRoll(.pinsLeft([]), ballID: nil, in: id)
        try store.games.recordRoll(.pinsLeft([.pin7, .pin10]), ballID: nil, in: id)
        try store.games.recordRoll(.pinsLeft([]), ballID: nil, in: id)
        guard case .frames(let leaves) = try load(id).leaves else { Issue.record("expected frames"); return }
        #expect(leaves.map(\.frameIndex) == [1, 2])
        #expect(leaves.map(\.leave.kind) == [.strike, .split])
    }

    @Test func countOnlyAsksForPins() throws {
        let id = try game(.countOnly)
        try store.games.recordRoll(.count(9), ballID: nil, in: id)
        #expect(try load(id).leaves == .enterPins)
    }

    @Test func finalScoreHasNoLeaves() throws {
        let id = try game(.finalOnly)
        try store.games.setFinalScore(180, for: id)
        #expect(try load(id).leaves == .hidden)
    }

    @Test func ballsUsedListsDefaultThenOverridesOnce() throws {
        let id = try game(.pinByPin, ball: phaze.id)
        for frame in 1...7 {
            let ball = frame == 3 || frame == 7 ? hammer.id : nil
            try store.games.recordRoll(.pinsLeft([]), ballID: ball, in: id)
        }
        let used = try load(id).ballsUsed
        #expect(used.map(\.text) == ["Default · Phaze", "Hammer · frames 3 and 7"])
        #expect(used.map(\.isDefault) == [true, false])
    }

    @Test func aSingleFrameOverrideReadsFrameNotFrames() throws {
        let id = try game(.pinByPin, ball: phaze.id)
        try store.games.recordRoll(.pinsLeft([]), ballID: nil, in: id)
        try store.games.recordRoll(.pinsLeft([]), ballID: hammer.id, in: id)
        #expect(try load(id).ballsUsed.map(\.text) == ["Default · Phaze", "Hammer · frame 2"])
    }

    @Test func noBallsNoRows() throws {
        let id = try game(.pinByPin)
        try store.games.recordRoll(.pinsLeft([]), ballID: nil, in: id)
        #expect(try load(id).ballsUsed == [])
    }

    @Test func aMissingBallReadsDeletedBall() throws {
        let id = try game(.pinByPin, ball: phaze.id)
        let data = try GameDetailData.load(id, from: store, ballName: { _ in nil })
        #expect(data.ballsUsed.map(\.text) == ["Default · Deleted ball"])
    }

    @Test func aRetiredBallKeepsItsName() throws {
        let id = try game(.pinByPin, ball: phaze.id)
        try store.balls.setRetired(true, for: phaze.id)
        #expect(try GameDetailData.load(id, from: store).ballsUsed.map(\.text) == ["Default · Phaze"])
    }

    @Test func latestFlag() throws {
        let session = try store.sessions.startSession(
            SessionMetadata(date: .now, eventType: .practice),
            bowlers: [(bowlerID: sam.id, defaultBallID: nil)], entryMode: .finalOnly
        )
        let first = try #require(try store.sessions.session(session).bowlers.first?.games.first?.id)
        let second = try #require(try store.games.startNextGame(in: session).first)
        #expect(try load(first).isLatest == false)
        #expect(try load(second).isLatest == true)
    }

    @Test func titleAndEditTarget() throws {
        let session = try store.sessions.startSession(
            SessionMetadata(date: .now, eventType: .practice),
            bowlers: [(bowlerID: sam.id, defaultBallID: nil)], entryMode: .finalOnly
        )
        _ = try store.games.startNextGame(in: session)
        let second = try #require(try store.sessions.session(session).bowlers.first?.games.last?.id)
        let data = try load(second)
        #expect(data.title == "Game 2 · Sam")
        #expect(data.editTarget == ScoringTarget(sessionID: session, gameID: second, startsOnTarget: true))
        #expect(data.deleteRequest.target == .game(second))
    }

    @Test func aDeletedGameThrows() throws {
        #expect(throws: RepositoryError.notFound) { try load(GameID()) }
    }
}
