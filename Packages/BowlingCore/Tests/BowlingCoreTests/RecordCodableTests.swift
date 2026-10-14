import Foundation
import Testing
import BowlingCore

@Suite struct RecordCodableTests {
    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    @Test func rollDefaults() {
        let roll = RollRecord(rollIndex: 1, pinCount: 7, pinsKnown: false)
        #expect(roll.pinsDown.isEmpty)
        #expect(!roll.isFoul)
        #expect(roll.ballID == nil)
    }

    @Test func rollRoundTrips() throws {
        let rolls = [
            RollRecord(rollIndex: 1, pinsDown: PinSet(pins: [1, 2, 3, 5, 8, 9]), pinCount: 6,
                       pinsKnown: true, ballID: BallID()),
            RollRecord(rollIndex: 2, pinCount: 0, pinsKnown: false, isFoul: true),
        ]
        for roll in rolls { #expect(try roundTrip(roll) == roll) }
    }

    @Test func gameRoundTrips() throws {
        let frame = FrameRecord(frameIndex: 1, rolls: [
            RollRecord(rollIndex: 1, pinsDown: PinSet.all.subtracting(.pin10), pinCount: 9, pinsKnown: true),
            RollRecord(rollIndex: 2, pinsDown: .pin10, pinCount: 1, pinsKnown: true),
        ])
        let game = GameRecord(
            bowlerID: BowlerID(), gameIndex: 2, entryMode: .pinByPin, defaultBallID: BallID(),
            finalScore: 10, isComplete: false, frames: [frame], sessionID: SessionID(),
            sessionDate: Date(timeIntervalSince1970: 1_790_000_000), eventType: .league
        )
        #expect(try roundTrip(game) == game)
    }

    @Test func finalOnlyGameRoundTrips() throws {
        let game = GameRecord(
            gameIndex: 1, entryMode: .finalOnly, finalScore: 187, isComplete: true,
            sessionDate: Date(timeIntervalSince1970: 0), eventType: .casual
        )
        #expect(game.frames.isEmpty)
        #expect(try roundTrip(game) == game)
    }

    @Test func gameWithUnknownEnumValueDecodes() throws {
        let game = GameRecord(
            gameIndex: 1, entryMode: .countOnly, finalScore: 0, isComplete: false,
            sessionDate: Date(timeIntervalSince1970: 0), eventType: .practice
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(game)) as? [String: Any]
        )
        object["entryMode"] = "voice"
        object["eventType"] = "funLeague"
        let decoded = try JSONDecoder().decode(
            GameRecord.self, from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(decoded.entryMode == .unknown)
        #expect(decoded.eventType == .unknown)
    }

    @Test func marksRoundTrip() throws {
        let marks: [Mark] = [.strike, .spare, .count(7), .gutter, .foul]
        #expect(try roundTrip(marks) == marks)
    }
}
