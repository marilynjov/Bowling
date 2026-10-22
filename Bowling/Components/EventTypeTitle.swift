import BowlingCore
import Foundation

extension EventType {
    /// The event's name in pickers and rows. `.unknown` comes from a newer build.
    var title: String {
        switch self {
        case .practice: String(localized: "Practice")
        case .league: String(localized: "League")
        case .tournament: String(localized: "Tournament")
        case .casual: String(localized: "Casual")
        case .unknown: String(localized: "Other")
        }
    }
}
