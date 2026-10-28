import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct GameRepositoryTests {
    let store: BowlingStore
    var games: GameRepository { store.games }
    let owner: BowlerRecord

    init() throws {
        store = try BowlingStore(inMemory: true)
        owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .casual)
    }

    private func startGame(_ mode: EntryMode, ball: BallID? = nil) throws -> GameRecord {
        let metadata = SessionMetadata(date: DemoFixture.referenceDate, eventType: .practice)
        let session = try store.sessions.startSession(metadata, bowlers: [(owner.id, ball)], entryMode: mode)
        return try #require(try store.sessions.session(session).bowlers.first?.games.first)
    }

    private static func count(_ rollIndex: Int, _ pins: Int) -> RollRecord {
        RollRecord(rollIndex: rollIndex, pinCount: pins, pinsKnown: false)
    }

    @Test func gameReadsBackWhatWasStarted() throws {
        let started = try startGame(.countOnly)
        #expect(try games.game(started.id) == started)
    }

    @Test func missingGameIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try games.game(UUID()) }
        #expect(throws: RepositoryError.notFound) { try games.deleteGame(UUID()) }
        #expect(throws: RepositoryError.notFound) { try games.setDefaultBall(nil, for: UUID()) }
    }

    // MARK: Saving a whole game

    @Test func saveStoresFramesAndRecomputesScoreAndCompletion() throws {
        var record = try startGame(.countOnly)
        record.frames = (1...9).map { FrameRecord(frameIndex: $0, rolls: [Self.count(1, 9), Self.count(2, 0)]) }
            + [FrameRecord(frameIndex: 10, rolls: [Self.count(1, 9), Self.count(2, 0)])]
        record.finalScore = 12
        record.isComplete = false

        let saved = try games.save(record)
        #expect(saved.finalScore == 90)
        #expect(saved.isComplete)
        #expect(try games.game(record.id) == saved)
    }

    @Test func incompleteGameCachesItsLastKnownRunningTotal() throws {
        var record = try startGame(.countOnly)
        record.frames = [
            FrameRecord(frameIndex: 1, rolls: [Self.count(1, 7), Self.count(2, 2)]),
            FrameRecord(frameIndex: 2, rolls: [Self.count(1, 10)]),
        ]
        let saved = try games.save(record)
        #expect(saved.finalScore == 9)
        #expect(!saved.isComplete)
    }

    @Test func invalidGameIsRefusedAndNothingChanges() throws {
        var record = try startGame(.countOnly)
        record.frames = [FrameRecord(frameIndex: 1, rolls: [Self.count(1, 7), Self.count(2, 5)])]

        #expect(throws: RepositoryError.invalidGame([.pinsExceedAvailable(frameIndex: 1, rollIndex: 2)])) {
            try games.save(record)
        }
        #expect(try games.game(record.id).frames.isEmpty)
        #expect(try store.context.fetchCount(FetchDescriptor<Roll>()) == 0)
    }

    @Test func saveWithUnknownEntryModeKeepsStoredRawValue() throws {
        let started = try startGame(.countOnly)
        try store.context.game(started.id).entryMode = "scannedLater"
        var record = try games.game(started.id)
        #expect(record.entryMode == .unknown)

        record.gameIndex = 4
        _ = try games.save(record)
        #expect(try store.context.game(started.id).entryMode == "scannedLater")
    }

    // MARK: Final score

    @Test func setFinalScoreCompletesAFinalOnlyGame() throws {
        let started = try startGame(.finalOnly)
        try games.setFinalScore(247, for: started.id)
        let game = try games.game(started.id)
        #expect(game.finalScore == 247)
        #expect(game.isComplete)
    }

    @Test func setFinalScoreOutOfRangeIsRefused() throws {
        let started = try startGame(.finalOnly)
        #expect(throws: RepositoryError.invalidGame([.finalScoreOutOfRange])) {
            try games.setFinalScore(301, for: started.id)
        }
        #expect(try games.game(started.id) == started)
    }

    @Test func setFinalScoreOnAScoredGameIsRefused() throws {
        let started = try startGame(.pinByPin)
        #expect(throws: RepositoryError.notFinalOnly) { try games.setFinalScore(200, for: started.id) }
        #expect(try games.game(started.id) == started)
    }

    // MARK: Default ball

    @Test func setDefaultBallLinksAndClears() throws {
        let ball = try store.balls.addBall(name: "Phaze", weightPounds: 15, intendedRole: .strike, brand: "")
        let started = try startGame(.pinByPin)
        try games.setDefaultBall(ball.id, for: started.id)
        #expect(try games.game(started.id).defaultBallID == ball.id)
        try games.setDefaultBall(nil, for: started.id)
        #expect(try games.game(started.id).defaultBallID == nil)
    }

    @Test func setDefaultBallToMissingBallIsNotFound() throws {
        let started = try startGame(.pinByPin)
        #expect(throws: RepositoryError.notFound) { try games.setDefaultBall(UUID(), for: started.id) }
    }

    // MARK: Next game and delete

    @Test func startNextGameContinuesEachBowlerWithTheSameModeAndBall() throws {
        let partner = try store.bowlers.createBowler(name: "Alex")
        let ball = try store.balls.addBall(name: "Phaze", weightPounds: 15, intendedRole: .strike, brand: "")
        let metadata = SessionMetadata(date: DemoFixture.referenceDate, eventType: .league)
        let session = try store.sessions.startSession(
            metadata, bowlers: [(owner.id, ball.id), (partner.id, nil)], entryMode: .countOnly
        )

        let next = try games.startNextGame(in: session)
        let created = try next.map { try games.game($0) }
        #expect(created.map(\.bowlerID) == [owner.id, partner.id])
        #expect(created.map(\.gameIndex) == [2, 2])
        #expect(created.map(\.entryMode) == [.countOnly, .countOnly])
        #expect(created.map(\.defaultBallID) == [ball.id, nil])
    }

    @Test func startNextGameKeepsTheLineupOrder() throws {
        let partner = try store.bowlers.createBowler(name: "Alex")
        let metadata = SessionMetadata(date: DemoFixture.referenceDate, eventType: .league)
        let session = try store.sessions.startSession(
            metadata, bowlers: [(partner.id, nil), (owner.id, nil)], entryMode: .pinByPin
        )

        let next = try games.startNextGame(in: session)
        #expect(try next.map { try games.game($0).bowlerID } == [partner.id, owner.id])
        let created = try store.context.fetch(FetchDescriptor<Game>()).filter { $0.gameIndex == 2 }
        #expect(Dictionary(uniqueKeysWithValues: created.map { ($0.bowler!.id, $0.lineupIndex) })
                == [partner.id: 1, owner.id: 2])
        #expect(try store.sessions.session(session).bowlers.map(\.bowler.id) == [partner.id, owner.id])
    }

    @Test func startNextGameOnAnEvenNightAddsOneToEveryone() throws {
        let partner = try store.bowlers.createBowler(name: "Alex")
        let metadata = SessionMetadata(date: DemoFixture.referenceDate, eventType: .league)
        let session = try store.sessions.startSession(
            metadata, bowlers: [(owner.id, nil), (partner.id, nil)], entryMode: .countOnly
        )

        let second = try games.startNextGame(in: session)
        let third = try games.startNextGame(in: session)
        #expect(try second.map { try games.game($0).gameIndex } == [2, 2])
        #expect(try third.map { try games.game($0).gameIndex } == [3, 3])
    }

    @Test func startNextGameNumbersEveryoneFromTheSessionsHighestGame() throws {
        let partner = try store.bowlers.createBowler(name: "Alex")
        let metadata = SessionMetadata(date: DemoFixture.referenceDate, eventType: .league)
        let session = try store.sessions.startSession(
            metadata, bowlers: [(owner.id, nil), (partner.id, nil)], entryMode: .countOnly
        )
        let second = try games.startNextGame(in: session)
        try games.deleteGame(second[1])

        let next = try games.startNextGame(in: session)
        let created = try next.map { try games.game($0) }
        #expect(created.map(\.bowlerID) == [owner.id, partner.id])
        #expect(created.map(\.gameIndex) == [3, 3])
    }

    @Test func startNextGameInMissingSessionIsNotFound() {
        #expect(throws: RepositoryError.notFound) { try games.startNextGame(in: UUID()) }
    }

    @Test func deleteGameCascadesToFramesAndRollsButKeepsTheSession() throws {
        var record = try startGame(.countOnly)
        record.frames = [FrameRecord(frameIndex: 1, rolls: [Self.count(1, 7), Self.count(2, 2)])]
        _ = try games.save(record)

        try games.deleteGame(record.id)
        #expect(try store.context.fetchCount(FetchDescriptor<Game>()) == 0)
        #expect(try store.context.fetchCount(FetchDescriptor<Frame>()) == 0)
        #expect(try store.context.fetchCount(FetchDescriptor<Roll>()) == 0)
        #expect(try store.context.fetchCount(FetchDescriptor<Session>()) == 1)
    }
}
