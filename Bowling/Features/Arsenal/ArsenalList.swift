import BowlingCore
import BowlingData
import Foundation

/// The Arsenal list (spec §1): active balls by name, each row's text.
struct ArsenalList: Hashable {
    struct Row: Hashable, Identifiable {
        var id: BallID
        var name: String
        /// "15 lb · Strike", or "15 lb" when the stored role is unknown.
        var detail: String
        /// "12 games", "1 game", or "No games yet".
        var games: String
        var accessibilityLabel: String
    }

    var rows: [Row]

    static func load(from store: BowlingStore) -> ArsenalList {
        ArsenalList(rows: store.balls.activeBalls().map {
            row(id: $0.id, name: $0.name, weightPounds: $0.weightPounds, role: $0.intendedRole, gamesBowled: $0.gamesBowled)
        })
    }

    /// One row; `load` maps each `BallSummary` through it (`BallSummary` has no public init).
    static func row(id: BallID, name: String, weightPounds: Int, role: BallRole, gamesBowled: Int) -> Row {
        let weight = String(localized: "\(weightPounds) lb")
        let games = switch gamesBowled {
        case 0: String(localized: "No games yet")
        case 1: String(localized: "1 game")
        default: String(localized: "\(gamesBowled) games")
        }
        return Row(
            id: id,
            name: name,
            detail: roleTitle(role).map { "\(weight) · \($0)" } ?? weight,
            games: games,
            accessibilityLabel: AccessibilityText.ballRow(
                name: name, weightPounds: weightPounds, role: role, gamesBowled: gamesBowled
            )
        )
    }

    /// Strike, Spare, Both; nil for a role written by a newer version.
    static func roleTitle(_ role: BallRole) -> String? {
        switch role {
        case .strike: String(localized: "Strike")
        case .spare: String(localized: "Spare")
        case .both: String(localized: "Both")
        case .unknown: nil
        }
    }
}
