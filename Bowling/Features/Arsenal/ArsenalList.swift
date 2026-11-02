import BowlingCore
import BowlingData
import Foundation

/// The Arsenal list (spec §7, Arsenal 1b): active balls by name, then the Retired group.
struct ArsenalList: Hashable {
    struct Row: Hashable, Identifiable {
        var id: BallID
        var name: String
        /// "Storm · 15 lb · Strike"; the brand is left out when blank, the role when unknown.
        var detail: String
        /// "12 games", "1 game", or "No games yet".
        var games: String
        var isResurfaceDue: Bool
        var isRetired: Bool
        var hasPhoto: Bool
        var placeholder: BallThumbnail.Placeholder
        var accessibilityLabel: String
    }

    var active: [Row]
    var retired: [Row]

    var isEmpty: Bool { active.isEmpty && retired.isEmpty }

    static func load(from store: BowlingStore) -> ArsenalList {
        ArsenalList(
            active: store.balls.activeBalls().map(row),
            retired: store.balls.retiredBalls().map(row)
        )
    }

    private static func row(_ ball: BallSummary) -> Row {
        row(id: ball.id, name: ball.name, brand: ball.brand, weightPounds: ball.weightPounds,
            role: ball.intendedRole, gamesBowled: ball.gamesBowled, isResurfaceDue: ball.isResurfaceDue,
            isRetired: ball.isRetired, hasPhoto: ball.hasPhoto)
    }

    /// One row; `load` maps each `BallSummary` through it (`BallSummary` has no public init).
    static func row(id: BallID, name: String, brand: String = "", weightPounds: Int, role: BallRole,
                    gamesBowled: Int, isResurfaceDue: Bool = false, isRetired: Bool = false,
                    hasPhoto: Bool = false) -> Row {
        let brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let weight = String(localized: "\(weightPounds) lb")
        let games = switch gamesBowled {
        case 0: String(localized: "No games yet")
        case 1: String(localized: "1 game")
        default: String(localized: "\(gamesBowled) games")
        }
        return Row(
            id: id,
            name: name,
            detail: [brand.isEmpty ? nil : brand, weight, roleTitle(role)].compactMap { $0 }.joined(separator: " · "),
            games: games,
            isResurfaceDue: isResurfaceDue,
            isRetired: isRetired,
            hasPhoto: hasPhoto,
            placeholder: BallThumbnail.Placeholder(id: id, name: name),
            accessibilityLabel: AccessibilityText.ballRow(
                name: name, brand: brand, weightPounds: weightPounds, role: role, gamesBowled: gamesBowled,
                isResurfaceDue: isResurfaceDue, isRetired: isRetired
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
