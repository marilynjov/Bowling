import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

/// The game `PinByPinGameUITests` plays, entered the same way through the model, so its
/// expected 193 is checked without the simulator UI. "Tap standing": the pins marked are
/// the ones left standing.
///
/// | Frame | 1 | 2   | 3   | 4  | 5  | 6   | 7   | 8   | 9   | 10    |
/// | Rolls | X | 7 / | 9 - | X  | X  | 8 / | 9 / | X   | 7 2 | X X X |
/// | Total | 20| 39  | 48  | 76 | 96 | 115 | 135 | 154 | 163 | 193   |
@Suite struct UITestGameTests {
    @Test func scoresOneNinetyThree() throws {
        let suite = UserDefaults(suiteName: "test.\(UUID())")!
        let app = AppModel(
            store: try BowlingStore(inMemory: true),
            sessionDefaults: SessionDefaultsStore(suite),
            scoringSettings: ScoringSettings(suite)
        )
        let sam = try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
        let target = try app.write { store in
            let session = try store.sessions.startSession(
                SessionMetadata(date: .now, eventType: .league), bowlers: [(sam.id, nil)], entryMode: .pinByPin
            )
            let game = try #require(try store.sessions.session(session).bowlers.first?.games.first)
            return ScoringTarget(sessionID: session, gameID: game.id)
        }
        let model = try ScoringModel(target: target, app: app, now: TestClock().tick)
        func pins(_ standing: Int...) {
            model.setShown(PinSet(pins: standing))
            model.next()
        }

        model.strike()                          // 1
        pins(4, 7, 10); model.spare()           // 2
        pins(10); model.miss()                  // 3
        model.strike()                          // 4
        model.strike()                          // 5
        pins(7, 10); model.spare()              // 6
        pins(10); model.spare()                 // 7
        model.strike()                          // 8
        pins(4, 7, 10); pins(10)                // 9
        model.strike(); model.strike(); model.strike() // 10

        #expect(model.game.isComplete)
        #expect(model.game.finalScore == 193)
        // What VoiceOver reads for each frame: docs/accessibility-checklist.md quotes these.
        #expect(model.scorecard.frames.map(AccessibilityText.frame) == [
            "Frame 1: strike, total 20",
            "Frame 2: 7, spare, total 39",
            "Frame 3: 9, gutter, total 48",
            "Frame 4: strike, total 76",
            "Frame 5: strike, total 96",
            "Frame 6: 8, spare, total 115",
            "Frame 7: 9, spare, total 135",
            "Frame 8: strike, total 154",
            "Frame 9: 7, 2, total 163",
            "Frame 10: strike, strike, strike, total 193",
        ])
        #expect(AccessibilityText.deckSummary(standing: PinSet(pins: [4, 7, 10])) == "3 pins standing: 4, 7, 10")
        #expect(AccessibilityText.deckSummary(standing: PinSet(pins: [10])) == "1 pin standing: 10")
    }
}
