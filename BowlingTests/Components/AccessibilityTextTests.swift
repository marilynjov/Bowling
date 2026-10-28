import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct AccessibilityTextTests {
    @Test func pins() {
        #expect(AccessibilityText.pin(7, standing: true) == "Pin 7, standing")
        #expect(AccessibilityText.pin(7, standing: false) == "Pin 7, down")
    }
    @Test func deckSummary() {
        #expect(AccessibilityText.deckSummary(standing: []) == "No pins standing")
        #expect(AccessibilityText.deckSummary(standing: .all) == "All 10 pins standing")
        #expect(AccessibilityText.deckSummary(standing: .pin10) == "1 pin standing: 10")
        #expect(AccessibilityText.deckSummary(standing: PinSet(pins: [4, 7, 8, 9, 10])) == "5 pins standing: 4, 7, 8, 9, 10")
    }
    @Test func frames() {
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 6, marks: [.foul, .count(7)], runningTotal: 105)) == "Frame 6: foul, 7, total 105")
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 1, marks: [.strike], runningTotal: 20)) == "Frame 1: strike, total 20")
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 2, marks: [.count(9), .spare], runningTotal: nil)) == "Frame 2: 9, spare")
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 4, marks: [.gutter, .count(3)], runningTotal: 60)) == "Frame 4: gutter, 3, total 60")
        #expect(AccessibilityText.frame(FrameScore(frameIndex: 8, marks: [], runningTotal: nil)) == "Frame 8: not bowled")
    }
    @Test func leaves() {
        #expect(AccessibilityText.leave(LeaveClassifier.classify(PinSet(pins: [3, 6, 10]))) == "Leave 3, 6, 10, makeable")
        #expect(AccessibilityText.leave(LeaveClassifier.classify(PinSet(pins: [7, 10]))) == "Leave 7, 10, split")
        #expect(AccessibilityText.leave(LeaveClassifier.classify(.pin10)) == "Leave 10, single pin")
        #expect(AccessibilityText.leave(LeaveClassifier.classify(PinSet(pins: [1, 2, 10]))) == "Leave 1, 2, 10, washout")
        #expect(AccessibilityText.leave(LeaveClassifier.classify([])) == "No leave, strike")
    }
    @Test func statTile() {
        #expect(AccessibilityText.statTile(title: "Strike %", value: "41%", sample: "216 frames") == "Strike %, 41%, 216 frames")
        #expect(AccessibilityText.statTile(title: "Average", value: "–", sample: nil) == "Average, no data")
    }
    @Test func bowlerChipReadsTheTurn() {
        #expect(AccessibilityText.bowlerChip(name: "Alex", score: 64, isCurrent: true, isFinished: false) == "Alex, 64, current turn")
        #expect(AccessibilityText.bowlerChip(name: "Sam", score: 87, isCurrent: false, isFinished: false) == "Sam, 87")
        #expect(AccessibilityText.bowlerChip(name: "Sam", score: 201, isCurrent: false, isFinished: true) == "Sam, 201, finished")
    }
    @Test func turnAnnouncement() {
        #expect(AccessibilityText.turn("Alex") == "Alex's turn")
    }
    @Test func sessionRowReadsAsOneLine() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12))!
        let row = RecentRow(
            id: SessionID(), date: date, eventType: .league, centerName: "AMF Bowl", scores: "201 · 189 · 224…",
            leagueName: "Tuesday Mixed", bowlerCount: 3, gameCount: 3, ownerScores: [201, 189, 224], isInProgress: true
        )
        #expect(AccessibilityText.sessionRow(row) == "October 21, League, AMF Bowl, Tuesday Mixed, 3 bowlers, 201, 189, 224, in progress")
    }
    @Test func historyDetailStrings() {
        #expect(AccessibilityText.bowlerHeader(name: "Alex", series: 590) == "Alex, series 590")
        #expect(AccessibilityText.gameRow(2, score: 189) == "Game 2, 189")
    }
    @Test func ballUseReadsFrames() {
        let use = GameDetailData.BallUse(id: BallID(), name: "Hammer", isDefault: false, frames: [3, 7], text: "Hammer · frames 3 and 7")
        #expect(AccessibilityText.ballUse(use) == "Hammer, frames 3 and 7")
    }

    @Test func ballRowReadsEveryPart() {
        #expect(AccessibilityText.ballRow(name: "Phaze", weightPounds: 15, role: .strike, gamesBowled: 12)
            == "Phaze, 15 pounds, strike, 12 games")
    }

    @Test func ballRowWithNoGames() {
        #expect(AccessibilityText.ballRow(name: "Phaze", weightPounds: 15, role: .strike, gamesBowled: 0)
            == "Phaze, 15 pounds, strike, no games yet")
    }

    @Test func ballRowLeavesOutAnUnknownRole() {
        #expect(AccessibilityText.ballRow(name: "Phaze", weightPounds: 15, role: .unknown, gamesBowled: 1)
            == "Phaze, 15 pounds, 1 game")
    }
}
