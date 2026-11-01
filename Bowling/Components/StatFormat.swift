import BowlingCore
import Foundation

/// The text a `StatTile` shows for a `Rate` or `Mean` and its sample size.
enum StatFormat {
    enum Unit { case games, frames, chances, firstBalls, leaves }

    /// A whole percent that never overstates: it stays at 99% until every attempt hits and
    /// at 1% or more once one does, so 199 of 200 isn't "100%" and 1 of 201 isn't "0%".
    /// Formatted for `locale`, so en_CO reads "41 %".
    static func percent(_ rate: Rate, locale: Locale = .current) -> String {
        guard let value = rate.value else { return "–" }
        var whole = Int((value * 100).rounded())
        if rate.hits < rate.attempts { whole = min(whole, 99) }
        if rate.hits > 0 { whole = max(whole, 1) }
        return (Double(whole) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// Up to one decimal, with no trailing ".0": "186", "186.5" (or "186,5" in es_CO).
    static func average(_ mean: Mean, locale: Locale = .current) -> String {
        guard let value = mean.value else { return "–" }
        return value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    static func sample(_ count: Int, _ unit: Unit) -> String {
        switch (unit, count) {
        case (.games, 0): String(localized: "No games yet")
        case (.frames, 0): String(localized: "No frames yet")
        case (.chances, 0): String(localized: "No chances yet")
        case (.firstBalls, 0): String(localized: "No first balls yet")
        case (.leaves, 0): String(localized: "No leaves yet")
        case (.games, 1): String(localized: "1 game")
        case (.games, _): String(localized: "\(count) games")
        case (.frames, 1): String(localized: "1 frame")
        case (.frames, _): String(localized: "\(count) frames")
        case (.chances, 1): String(localized: "1 chance")
        case (.chances, _): String(localized: "\(count) chances")
        case (.firstBalls, 1): String(localized: "1 first ball")
        case (.firstBalls, _): String(localized: "\(count) first balls")
        case (.leaves, 1): String(localized: "1 leave")
        case (.leaves, _): String(localized: "\(count) leaves")
        }
    }
}
