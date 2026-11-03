import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct LeaveOccurrenceRowsTests {
    let us = Locale(identifier: "en_US")
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    let session = SessionID()
    let phaze = BallID()
    /// Oct 14, 2026, 20:00 UTC.
    let date = Date(timeIntervalSince1970: 1_792_008_000)

    func occurrence(game: Int = 2, frame: Int = 7, ball: BallID?, made: Bool) -> LeaveOccurrence {
        LeaveOccurrence(game: GameRef(gameID: GameID(), sessionID: session, date: date),
                        gameIndex: game, frameIndex: frame, ballID: ball, isConverted: made)
    }

    func rows(_ occurrences: [LeaveOccurrence]) -> [LeaveOccurrenceRow] {
        LeaveOccurrenceRows.make(occurrences, sessions: [session: "League · AMF Bowl · Tuesday Mixed"],
                                 balls: [phaze: "Phaze II"], calendar: utc, locale: us)
    }

    @Test func rowText() throws {
        let occurrence = occurrence(ball: phaze, made: true)
        let row = try #require(rows([occurrence]).first)
        #expect(row.id == occurrence.id)
        #expect(row.gameID == occurrence.game.gameID)
        #expect(row.sessionID == session)
        #expect(row.date == "Oct 14")
        #expect(row.session == "League · AMF Bowl · Tuesday Mixed")
        #expect(row.position == "Game 2 · Frame 7 · Phaze II")
        #expect(row.result == "Made")
        #expect(row.isConverted)
        #expect(row.accessibilityLabel == "Oct 14, League, AMF Bowl, Tuesday Mixed, game 2, frame 7, Phaze II, made")
    }

    @Test func ballFallbacks() {
        let rows = rows([occurrence(ball: nil, made: false), occurrence(ball: BallID(), made: false)])
        #expect(rows.map(\.position) == ["Game 2 · Frame 7 · No ball", "Game 2 · Frame 7 · Unknown ball"])
        #expect(rows.map(\.result) == ["Missed", "Missed"])
    }

    @Test func unknownSessionLeavesItsLineEmpty() throws {
        let other = LeaveOccurrence(game: GameRef(gameID: GameID(), sessionID: SessionID(), date: date),
                                    gameIndex: 1, frameIndex: 3, ballID: phaze, isConverted: true)
        let row = try #require(rows([other]).first)
        #expect(row.session == "")
        #expect(row.accessibilityLabel == "Oct 14, game 1, frame 3, Phaze II, made")
    }

    @Test func summaryCountsMade() {
        let seven = Array(repeating: occurrence(ball: phaze, made: true), count: 7)
            + Array(repeating: occurrence(ball: phaze, made: false), count: 2)
        #expect(LeaveOccurrenceRows.summary(seven, locale: us) == "Made 7 of 9 · 78%")
        #expect(LeaveOccurrenceRows.summary([], locale: us) == "Made 0 of 0 · –")
    }
}
