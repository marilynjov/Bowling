import BowlingCore
import BowlingFixtures
import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct ConversionTests {
    let store: BowlingStore
    var context: ModelContext { store.context }

    init() throws {
        store = try BowlingStore(inMemory: true)
    }

    @Test(arguments: DemoFixture.games(relativeTo: DemoFixture.referenceDate))
    func fixtureGameRoundTrips(_ record: GameRecord) throws {
        let game = try insertGame(record, into: context)
        #expect(game.record() == record)
    }

    @Test func pinMaskMapsBitForBit() throws {
        let roll = Roll(rollIndex: 1, pinsDownMask: 0b10_0000_0101, pinCount: 3, pinsKnown: true)
        #expect(roll.record().pinsDown == PinSet(pins: [1, 3, 10]))

        let record = RollRecord(rollIndex: 1, pinsDown: PinSet(pins: [2, 9]), pinCount: 2, pinsKnown: true)
        let game = try insertGame(Self.game(frames: [FrameRecord(frameIndex: 1, rolls: [record])]), into: context)
        #expect(game.frames?.first?.rolls?.first?.pinsDownMask == 0b01_0000_0010)
    }

    @Test func framesAndRollsInsertedInShuffledOrderConvertSorted() throws {
        let perfect = DemoFixture.games(relativeTo: DemoFixture.referenceDate)
            .first { $0.finalScore == 300 }!
        var generator = SeededGenerator(state: 21)
        var shuffled = perfect
        shuffled.id = UUID()
        shuffled.frames = perfect.frames.shuffled(using: &generator).map {
            FrameRecord(frameIndex: $0.frameIndex, rolls: $0.rolls.shuffled(using: &generator))
        }
        #expect(shuffled.frames.map(\.frameIndex) != perfect.frames.map(\.frameIndex))

        let game = try insertGame(shuffled, into: context)
        var converted = game.record()
        #expect(converted.frames == perfect.frames)
        #expect(Scorer.scorecard(for: converted).finalScore == 300)
        converted.id = perfect.id
        #expect(converted == perfect)
    }

    @Test func gameWithoutSessionConvertsWithUnknownEventType() throws {
        let game = Game(gameIndex: 1)
        context.insert(game)
        let record = game.record()
        #expect(record.sessionID == nil)
        #expect(record.eventType == .unknown)
        #expect(record.sessionDate == game.createdAt)
    }

    // MARK: Unknown raw values

    @Test func unknownStoredEntryModeAndEventTypeConvertToUnknown() throws {
        let game = try insertGame(Self.game(frames: []), into: context)
        game.entryMode = "scannedLater"
        game.session?.eventType = "bowlathon"

        let record = game.record()
        #expect(record.entryMode == .unknown)
        #expect(record.eventType == .unknown)
    }

    @Test func applyingUnknownEntryModeKeepsStoredRawValue() throws {
        let game = try insertGame(Self.game(frames: []), into: context)
        game.entryMode = "scannedLater"

        var record = game.record()
        record.gameIndex = 2
        try game.apply(record, in: context)
        #expect(game.entryMode == "scannedLater")
        #expect(game.gameIndex == 2)
    }

    // MARK: Writing back

    @Test func applyUpdatesExistingRowsInPlace() throws {
        let first = FrameRecord(frameIndex: 1, rolls: [Self.count(1, 7)])
        let game = try insertGame(Self.game(frames: [first]), into: context)
        let frameID = try #require(game.frames?.first?.id)
        let rollID = try #require(game.frames?.first?.rolls?.first?.id)

        var record = game.record()
        record.frames[0].rolls.append(Self.count(2, 2))
        try game.apply(record, in: context)

        #expect(game.frames?.map(\.id) == [frameID])
        #expect(game.frames?.first?.rolls?.contains { $0.id == rollID } == true)
        #expect(game.record().frames == record.frames)
    }

    @Test func applyDeletesRowsTheRecordNoLongerHas() throws {
        let frames = [
            FrameRecord(frameIndex: 1, rolls: [Self.count(1, 7), Self.count(2, 2)]),
            FrameRecord(frameIndex: 2, rolls: [Self.count(1, 4)]),
        ]
        let game = try insertGame(Self.game(frames: frames), into: context)

        var record = game.record()
        record.frames = [FrameRecord(frameIndex: 1, rolls: [Self.count(1, 7)])]
        try game.apply(record, in: context)
        try context.save()

        #expect(game.record().frames == record.frames)
        #expect(try context.fetchCount(FetchDescriptor<Frame>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Roll>()) == 1)
    }

    @Test func applyLinksRollBallOverrideAndDefaultBall() throws {
        let strikeBall = UUID(), spareBall = UUID()
        var record = Self.game(frames: [
            FrameRecord(frameIndex: 1, rolls: [Self.count(1, 7), Self.count(2, 3, ball: spareBall)]),
        ])
        record.defaultBallID = strikeBall
        let game = try insertGame(record, into: context)

        #expect(game.defaultBall?.id == strikeBall)
        #expect(game.record().frames[0].rolls.map(\.ballID) == [nil, spareBall])
    }

    @Test func applyRefusesUnknownBall() throws {
        let game = try insertGame(Self.game(frames: []), into: context)
        var record = game.record()
        record.defaultBallID = UUID()
        #expect(throws: RepositoryError.notFound) { try game.apply(record, in: context) }
    }

    // MARK: Helpers

    static func game(frames: [FrameRecord]) -> GameRecord {
        GameRecord(
            gameIndex: 1, entryMode: .countOnly, finalScore: 0, isComplete: false,
            frames: frames, sessionID: UUID(), sessionDate: DemoFixture.referenceDate, eventType: .casual
        )
    }

    static func count(_ rollIndex: Int, _ pins: Int, ball: BallID? = nil) -> RollRecord {
        RollRecord(rollIndex: rollIndex, pinCount: pins, pinsKnown: false, ballID: ball)
    }
}
