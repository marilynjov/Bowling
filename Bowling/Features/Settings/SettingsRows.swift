import BowlingCore
import BowlingData
import Foundation

/// Settings' text and current choices for the owner (spec §1).
struct SettingsRows: Hashable {
    /// Where Stats and Home start: the owner's `statsScope`.
    enum DefaultGames: Hashable, CaseIterable {
        case follow, competition, allGames

        var scope: StatsScope? {
            switch self {
            case .follow: nil
            case .competition: .competition
            case .allGames: .all
            }
        }
    }

    static let styles: [StatsProfile] = [.casual, .league, .competitive]

    /// "Sam · Right-handed"; just the name for a hand from a newer version.
    var profileSummary: String
    /// Nil for a style from a newer version, so the picker shows no selection.
    var style: StatsProfile?
    /// A scope from a newer version reads as Follow.
    var defaultGames: DefaultGames
    private var prefersCompetition: Bool

    init(owner: BowlerRecord) {
        profileSummary = switch owner.handedness {
        case .right: String(localized: "\(owner.name) · Right-handed")
        case .left: String(localized: "\(owner.name) · Left-handed")
        case .unknown: owner.name
        }
        style = owner.statsProfile == .unknown ? nil : owner.statsProfile
        defaultGames = switch owner.statsScope {
        case .competition: .competition
        case .all: .allGames
        case nil, .unknown: .follow
        }
        prefersCompetition = StatsPreset.prefersCompetition(owner.statsProfile)
    }

    /// Follow names what the bowling style picks: "Follow bowling style (Competition)".
    func title(_ games: DefaultGames) -> String {
        switch games {
        case .follow:
            prefersCompetition
                ? String(localized: "Follow bowling style (Competition)")
                : String(localized: "Follow bowling style (All games)")
        case .competition: String(localized: "Competition")
        case .allGames: String(localized: "All games")
        }
    }

    static func title(_ style: StatsProfile) -> String {
        switch style {
        case .casual, .unknown: String(localized: "Casual")
        case .league: String(localized: "League")
        case .competitive: String(localized: "Competitive")
        }
    }
}
