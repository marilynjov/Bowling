import BowlingCore
import Foundation

/// Every VoiceOver string the shared components read (spec §10), kept out of the views so
/// the exact wording is unit tested.
enum AccessibilityText {
    static func pin(_ number: Int, standing: Bool) -> String {
        standing
            ? String(localized: "Pin \(number), standing")
            : String(localized: "Pin \(number), down")
    }

    static func deckSummary(standing: PinSet) -> String {
        let pins = standing.pins.map(String.init).joined(separator: ", ")
        switch standing.count {
        case 0: return String(localized: "No pins standing")
        case 10: return String(localized: "All 10 pins standing")
        case 1: return String(localized: "1 pin standing: \(pins)")
        default: return String(localized: "\(standing.count) pins standing: \(pins)")
        }
    }

    static func frame(_ frame: FrameScore) -> String {
        guard !frame.marks.isEmpty else {
            return String(localized: "Frame \(frame.frameIndex): not bowled")
        }
        var parts = frame.marks.map(word(for:))
        if let total = frame.runningTotal {
            parts.append(String(localized: "total \(total)"))
        }
        return String(localized: "Frame \(frame.frameIndex): \(parts.joined(separator: ", "))")
    }

    static func leave(_ leave: Leave) -> String {
        guard leave.kind != .strike else { return String(localized: "No leave, strike") }
        let pins = leave.pins.pins.map(String.init).joined(separator: ", ")
        return String(localized: "Leave \(pins), \(kindWord(for: leave))")
    }

    /// A bowler strip chip: "Alex, 64, current turn" / "Sam, 87" / "Sam, 201, finished".
    static func bowlerChip(name: String, score: Int, isCurrent: Bool, isFinished: Bool) -> String {
        if isCurrent { return String(localized: "\(name), \(score), current turn") }
        if isFinished { return String(localized: "\(name), \(score), finished") }
        return "\(name), \(score)"
    }

    /// Announced when the turn moves to another bowler.
    static func turn(_ name: String) -> String {
        String(localized: "\(name)'s turn")
    }

    /// A tile with no data shows "–", which VoiceOver would read as "en dash".
    static func statTile(title: String, value: String, sample: String?) -> String {
        let spoken = value == "–" ? String(localized: "no data") : value
        return ([title, spoken] + [sample].compactMap { $0 }).joined(separator: ", ")
    }

    /// The Stats trend card as one element: "Trend, 12 sessions, latest session 201,
    /// rolling average 195".
    static func trend(sessions: Int, latest: String, rolling: String) -> String {
        let count = sessions == 1 ? String(localized: "1 session") : String(localized: "\(sessions) sessions")
        return String(localized: "Trend, \(count), latest session \(latest), rolling average \(rolling)")
    }

    /// A Stats leaves row: "Leave 7, 10, split, made 2 of 9".
    static func leaveRow(_ leave: Leave, made: Int, of count: Int) -> String {
        self.leave(leave) + ", " + String(localized: "made \(made) of \(count)")
    }

    private static func word(for mark: Mark) -> String {
        switch mark {
        case .strike: String(localized: "strike")
        case .spare: String(localized: "spare")
        case .foul: String(localized: "foul")
        case .gutter: String(localized: "gutter")
        case .count(let pins): "\(pins)"
        }
    }

    private static func kindWord(for leave: Leave) -> String {
        if leave.isWashout { return String(localized: "washout") }
        switch leave.kind {
        case .singlePin: return String(localized: "single pin")
        case .split: return String(localized: "split")
        case .makeable, .strike: return String(localized: "makeable")
        }
    }
}
