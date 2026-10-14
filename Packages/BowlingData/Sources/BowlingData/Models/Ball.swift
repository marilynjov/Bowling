import Foundation
import SwiftData

@Model
final class Ball {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var remoteID: String?

    var name: String = ""
    var brand: String = ""
    /// 6 through 16. The 0 default only exists for CloudKit; `init` requires a weight.
    var weightPounds: Int = 0
    var coverstock: String = Coverstock.unknown.rawValue
    /// Manufacturer's coverstock name, for example "SPEC Solid".
    var coverstockName: String = ""
    var coreType: String = CoreType.unknown.rawValue
    var coreName: String = ""
    var rg: Double?
    var differential: Double?
    /// Asymmetric cores only. Also called mass bias differential.
    var intermediateDifferential: Double?
    var intendedRole: String = IntendedRole.strike.rawValue
    var serialNumber: String = ""
    var colorDescription: String = ""
    /// Month precision.
    var releaseDate: Date?
    var purchaseDate: Date?
    /// Out-of-box surface, for example "2000 Abralon".
    var factoryFinish: String = ""
    /// Current surface, for example "2000 polished".
    var surfaceGrit: String = ""
    /// Nil means no resurface reminder.
    var resurfaceIntervalGames: Int?
    var isRetired: Bool = false
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \BallPhoto.ball)
    var photo: BallPhoto?

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceEvent.ball)
    var maintenance: [MaintenanceEvent]?

    @Relationship(deleteRule: .nullify, inverse: \Game.defaultBall)
    var gamesAsDefault: [Game]?

    @Relationship(deleteRule: .nullify, inverse: \Roll.ball)
    var rollsAsOverride: [Roll]?

    init(name: String, weightPounds: Int) {
        self.name = name
        self.weightPounds = weightPounds
    }
}

extension Ball {
    enum Coverstock: String, StoredEnum {
        case plastic, urethane, reactiveSolid, reactivePearl, reactiveHybrid, other, unknown
        static let fallback = Self.unknown
    }

    /// `pancake` is the plastic spare-ball core.
    enum CoreType: String, StoredEnum {
        case symmetric, asymmetric, pancake, unknown
        static let fallback = Self.unknown
    }

    enum IntendedRole: String, StoredEnum {
        case strike, spare, both
        static let fallback = Self.strike
    }

    var coverstockValue: Coverstock {
        get { Coverstock(stored: coverstock) }
        set { coverstock = newValue.rawValue }
    }

    var coreTypeValue: CoreType {
        get { CoreType(stored: coreType) }
        set { coreType = newValue.rawValue }
    }

    var intendedRoleValue: IntendedRole {
        get { IntendedRole(stored: intendedRole) }
        set { intendedRole = newValue.rawValue }
    }
}
