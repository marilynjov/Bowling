import BowlingCore
import Foundation

/// What the new-session form remembers for one event type (Phase 1 spec §7).
struct SessionDefaults: Codable, Hashable {
    var centerID: CenterID?
    var leagueID: LeagueID?
    var oilPatternID: OilPatternID?
    /// The owner's ball.
    var ballID: BallID?
    var entryMode: EntryMode?
}

/// Remembered values per event type, kept on this device in UserDefaults, never synced.
struct SessionDefaultsStore {
    private let defaults: UserDefaults

    init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Nothing remembered, or unreadable data, reads as empty.
    func defaults(for eventType: EventType) -> SessionDefaults {
        guard let data = defaults.data(forKey: Self.key(eventType)),
              let saved = try? JSONDecoder().decode(SessionDefaults.self, from: data)
        else { return SessionDefaults() }
        return saved
    }

    /// Also makes `eventType` the one the next form opens on.
    func save(_ values: SessionDefaults, for eventType: EventType) {
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: Self.key(eventType))
        }
        defaults.set(eventType.rawValue, forKey: Self.lastEventTypeKey)
    }

    /// The last started session's event type; Practice the first time.
    var lastEventType: EventType {
        let type = EventType(storedValue: defaults.string(forKey: Self.lastEventTypeKey) ?? "")
        return type == .unknown ? .practice : type
    }

    private static func key(_ eventType: EventType) -> String {
        "newSession.defaults.\(eventType.rawValue)"
    }

    private static let lastEventTypeKey = "newSession.lastEventType"
}
