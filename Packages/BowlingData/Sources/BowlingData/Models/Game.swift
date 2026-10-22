import Foundation
import SwiftData

@Model
final class Game {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var session: Session?
    /// Set only through `assign(_:)`, which keeps `bowlerID` in step.
    private(set) var bowler: Bowler?
    /// Copy of `bowler.id`. Survives the bowler being deleted, or not imported yet, so sync
    /// can tell those games from ones that never had a bowler (#89).
    var bowlerID: UUID?
    /// 1-based order within the session for this bowler.
    var gameIndex: Int = 1
    /// 1-based position of the bowler in the session's lineup, the order Scoring rotates
    /// through. Every game of one bowler in a session carries the same value.
    var lineupIndex: Int = 1
    var entryMode: String = EntryMode.pinByPin.rawValue
    var defaultBall: Ball?
    /// Cached. Scorer output for pinByPin and countOnly, typed by the user for finalOnly.
    var finalScore: Int = 0
    var isComplete: Bool = false
    /// Rolls this game holds, written with them by `apply(_:in:)`. Kept on the Game row so
    /// sync code can rank and check a game before its Frame and Roll rows have arrived.
    var recordedRollCount: Int = 0

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
    /// The only way to set `bowler`, so `bowlerID` always matches it.
    func assign(_ bowler: Bowler?) {
        self.bowler = bowler
        bowlerID = bowler?.id
    }

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
