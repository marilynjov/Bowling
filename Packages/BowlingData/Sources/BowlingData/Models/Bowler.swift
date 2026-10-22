import Foundation
import SwiftData

@Model
final class Bowler {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var name: String = ""
    var isOwner: Bool = false
    var handedness: String = Handedness.unknown.rawValue
    /// A third party's address for phase 7 invitations. Encrypted in CloudKit, which can
    /// only be chosen when the field is first created.
    @Attribute(.allowsCloudEncryption)
    var email: String?
    var statsProfile: String = StatsProfile.unknown.rawValue
    /// Comma-separated stats card IDs. Empty means the profile's preset.
    var statsLayout: String = ""
    /// Comma-separated Home tile card IDs. Empty means the profile's preset.
    var homeLayout: String = ""
    /// The explicit default stats scope. Empty follows the bowling style, which a style
    /// change never overwrites.
    var statsScope: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Game.bowler)
    var games: [Game]?

    init(name: String, isOwner: Bool = false) {
        self.name = name
        self.isOwner = isOwner
    }
}

extension Bowler {
    enum Handedness: String, StoredEnum {
        case right, left, unknown
        static let fallback = Self.unknown
    }

    /// `unknown` is treated as casual by the stats presets.
    enum StatsProfile: String, StoredEnum {
        case casual, league, competitive, unknown
        static let fallback = Self.unknown
    }

    var handednessValue: Handedness {
        get { Handedness(stored: handedness) }
        set { handedness = newValue.rawValue }
    }

    var statsProfileValue: StatsProfile {
        get { StatsProfile(stored: statsProfile) }
        set { statsProfile = newValue.rawValue }
    }
}
