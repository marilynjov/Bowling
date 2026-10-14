import Foundation
import SwiftData

@Model
final class BowlingCenter {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var name: String = ""
    var notes: String = ""
    var city: String?
    var latitude: Double?
    var longitude: Double?

    @Relationship(deleteRule: .nullify, inverse: \Session.center)
    var sessions: [Session]?

    @Relationship(deleteRule: .nullify, inverse: \League.center)
    var leagues: [League]?

    init(name: String) {
        self.name = name
    }
}

@Model
final class League {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var name: String = ""
    var notes: String = ""
    var center: BowlingCenter?
    var seasonLabel: String = ""
    var seasonStart: Date?
    var seasonEnd: Date?
    var gamesPerSession: Int = 3

    @Relationship(deleteRule: .nullify, inverse: \Session.league)
    var sessions: [Session]?

    init(name: String) {
        self.name = name
    }
}

/// A pattern the user created. Links to the bundled, non-synced library only through
/// `patternKey`, never by relationship, so the library is never copied into the synced store.
@Model
final class OilPattern {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var name: String = ""
    var notes: String = ""
    var lengthFeet: Int?
    var volumeMilliliters: Double?
    var patternKey: String?

    @Relationship(deleteRule: .nullify, inverse: \Session.oilPattern)
    var sessions: [Session]?

    init(name: String) {
        self.name = name
    }
}
