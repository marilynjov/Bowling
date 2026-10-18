import BowlingCore
import Foundation

/// The text a `StatTile` shows for a `Rate` or `Mean` and its sample size.
enum StatFormat {
    enum Unit { case games, frames, chances }

    /// A whole percent. It stops at 99% until every attempt hits, so 199 of 200 never
    /// reads as perfect. Formatted for `locale`, so en_CO reads "41 %".
    static func percent(_ rate: Rate, locale: Locale = .current) -> String {
        guard let value = rate.value else { return "–" }
        var whole = Int((value * 100).rounded())
        if rate.hits < rate.attempts { whole = min(whole, 99) }
        return (Double(whole) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// Up to one decimal, with no trailing ".0": "186", "186.5" (or "186,5" in en_CO).
    static func average(_ mean: Mean, locale: Locale = .current) -> String {
        guard let value = mean.value else { return "–" }
        return value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    static func sample(_ count: Int, _ unit: Unit) -> String {
        switch (unit, count) {
        case (_, 0): String(localized: "No games yet")
        case (.games, 1): String(localized: "1 game")
        case (.games, _): String(localized: "\(count) games")
        case (.frames, 1): String(localized: "1 frame")
        case (.frames, _): String(localized: "\(count) frames")
        case (.chances, 1): String(localized: "1 chance")
        case (.chances, _): String(localized: "\(count) chances")
        }
    }
}
