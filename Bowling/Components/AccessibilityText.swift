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

    /// A ball row on the game detail: "Hammer, frames 3 and 7" / "Phaze, default".
    static func ballUse(_ use: GameDetailData.BallUse) -> String {
        guard !use.isDefault else { return String(localized: "\(use.name), default") }
        let list = use.frames.map(String.init).formatted(.list(type: .and))
        return use.frames.count == 1
            ? String(localized: "\(use.name), frame \(list)")
            : String(localized: "\(use.name), frames \(list)")
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

    /// A by-frame bar: "Frame 1, 25%".
    static func byFrameBar(_ frame: Int, _ rate: String) -> String {
        String(localized: "Frame \(frame), \(rate)")
    }

    /// A by-frame average bar: "Frame 1, 7.5 pins".
    static func byFrameBar(_ frame: Int, pins: String) -> String {
        String(localized: "Frame \(frame), \(pins) pins")
    }

    /// "What if, 6 pin-by-pin games, your average 196, 205.3 with every single-pin spare
    /// made, 9.3 more pins a game". `gain` is the spoken gain, "9.3 more pins a game".
    static func whatIf(sample: String, actual: String, allMade: String, gain: String) -> String {
        String(localized: "What if, \(sample), your average \(actual), \(allMade) with every single-pin spare made, \(gain)")
    }

    /// "What if, 6 pin-by-pin games, your average 196, you made every single-pin spare."
    static func whatIf(sample: String, actual: String, note: String) -> String {
        String(localized: "What if, \(sample), your average \(actual), \(note)")
    }

    /// Read-only filter chips: "Filter: All time, All games, Sam".
    static func filterChips(_ chips: [String]) -> String {
        String(localized: "Filter: \(chips.joined(separator: ", "))")
    }

    /// A Stats card that explains instead of showing a number: "Strike %, Enter frames to
    /// see strikes and spares."
    static func explainedCard(title: String, text: String) -> String {
        "\(title), \(text)"
    }

    /// A Stats leaves row: "Leave 7, 10, split, made 2 of 9".
    static func leaveRow(_ leave: Leave, made: Int, of count: Int) -> String {
        self.leave(leave) + ", " + String(localized: "made \(made) of \(count)")
    }

    /// A session row read as one line: "October 21, League, AMF Bowl, Tuesday Mixed, 3 bowlers,
    /// 201, 189, in progress".
    static func sessionRow(_ row: RecentRow) -> String {
        var parts = [
            row.date.formatted(Date.FormatStyle().month(.wide).day()),
            row.eventType.title, row.centerName, row.leagueName, row.bowlersText,
        ].compactMap { $0 }
        parts += row.ownerScores.map(String.init)
        if row.isInProgress { parts.append(String(localized: "in progress")) }
        return parts.joined(separator: ", ")
    }

    /// A session detail bowler header: "Alex, series 590".
    static func bowlerHeader(name: String, series: Int) -> String {
        String(localized: "\(name), series \(series)")
    }

    /// A session detail game row: "Game 2, 189".
    static func gameRow(_ gameIndex: Int, score: Int) -> String {
        String(localized: "Game \(gameIndex), \(score)")
    }

    /// An Arsenal row: "Phaze, 15 pounds, strike, 12 games"; an unknown role is left out.
    /// A blank brand is left out; "resurface due" and "retired" follow the game count.
    static func ballRow(name: String, brand: String = "", weightPounds: Int, role: BallRole, gamesBowled: Int,
                        isResurfaceDue: Bool = false, isRetired: Bool = false) -> String {
        let roleWord: String? = switch role {
        case .strike: String(localized: "strike")
        case .spare: String(localized: "spare")
        case .both: String(localized: "both")
        case .unknown: nil
        }
        let games = switch gamesBowled {
        case 0: String(localized: "no games yet")
        case 1: String(localized: "1 game")
        default: String(localized: "\(gamesBowled) games")
        }
        let brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        return ([
            name,
            brand.isEmpty ? nil : brand,
            String(localized: "\(weightPounds) pounds"),
            roleWord,
            games,
            isResurfaceDue ? String(localized: "resurface due") : nil,
            isRetired ? String(localized: "retired") : nil,
        ].compactMap { $0 })
            .joined(separator: ", ")
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
