import Foundation
import SwiftData

@Model
final class MaintenanceEvent {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var ball: Ball?
    var date: Date = Date.now
    var kind: String = Kind.other.rawValue
    /// Copied to `Ball.surfaceGrit` on save when non-empty.
    var surfaceGritAfter: String = ""
    /// Snapshot of games bowled on the ball when the event was logged.
    var gamesOnBallAtTime: Int = 0
    var notes: String = ""

    init(date: Date, kind: Kind) {
        self.date = date
        self.kind = kind.rawValue
    }
}

extension MaintenanceEvent {
    enum Kind: String, StoredEnum {
        case resurface, polish, oilExtraction, plugAndRedrill, other
        static let fallback = Self.other
    }

    var kindValue: Kind {
        get { Kind(stored: kind) }
        set { kind = newValue.rawValue }
    }
}
