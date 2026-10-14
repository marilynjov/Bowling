import Foundation
import SwiftData

@Model
final class Game {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var session: Session?
    var bowler: Bowler?
    /// 1-based order within the session for this bowler.
    var gameIndex: Int = 1
    var entryMode: String = EntryMode.pinByPin.rawValue
    var defaultBall: Ball?
    /// Cached. Scorer output for pinByPin and countOnly, typed by the user for finalOnly.
    var finalScore: Int = 0
    var isComplete: Bool = false

    /// Unordered; sort by `Frame.frameIndex`. Empty for finalOnly games.
    @Relationship(deleteRule: .cascade, inverse: \Frame.game)
    var frames: [Frame]?

    @Relationship(deleteRule: .cascade, inverse: \GamePhoto.game)
    var photo: GamePhoto?

    var scanConfidence: Double?
    var invitationStatus: String = InvitationStatus.none.rawValue
    /// Set on the recipient's copy of an accepted invitation.
    var scoredByName: String?

    init(gameIndex: Int, entryMode: EntryMode = .pinByPin) {
        self.gameIndex = gameIndex
        self.entryMode = entryMode.rawValue
    }
}

extension Game {
    enum EntryMode: String, StoredEnum {
        case pinByPin, countOnly, finalOnly
        static let fallback = Self.pinByPin
    }

    enum InvitationStatus: String, StoredEnum {
        case none, sent, accepted, declined, expired
        static let fallback = Self.none
    }

    var entryModeValue: EntryMode {
        get { EntryMode(stored: entryMode) }
        set { entryMode = newValue.rawValue }
    }

    var invitationStatusValue: InvitationStatus {
        get { InvitationStatus(stored: invitationStatus) }
        set { invitationStatus = newValue.rawValue }
    }
}
