import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var date: Date = Date.now
    var eventType: String = EventType.casual.rawValue
    var center: BowlingCenter?
    /// Only meaningful when `eventType` is league.
    var league: League?
    var oilPattern: OilPattern?
    /// Free text, for example "17-18".
    var lanes: String = ""
    var notes: String = ""

    /// Unordered; sort by `Game.gameIndex`.
    @Relationship(deleteRule: .cascade, inverse: \Game.session)
    var games: [Game]?

    init(date: Date, eventType: EventType = .casual) {
        self.date = date
        self.eventType = eventType.rawValue
    }
}

extension Session {
    enum EventType: String, StoredEnum {
        case practice, league, tournament, casual
        static let fallback = Self.casual
    }

    var eventTypeValue: EventType {
        get { EventType(stored: eventType) }
        set { eventType = newValue.rawValue }
    }
}
