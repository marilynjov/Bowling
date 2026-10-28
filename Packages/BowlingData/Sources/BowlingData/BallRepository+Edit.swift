import BowlingCore
import Foundation
import SwiftData

/// Every editable Ball field (§3.2 Ball), the 1b add and edit form's values (§7 Arsenal 1b).
public struct BallFields: Sendable, Hashable {
    public var name: String
    public var brand: String
    /// 6 through 16.
    public var weightPounds: Int
    public var coverstock: Coverstock
    public var coverstockName: String
    public var coreType: CoreType
    public var coreName: String
    public var rg: Double?
    public var differential: Double?
    /// Asymmetric cores only.
    public var intermediateDifferential: Double?
    /// `.unknown` keeps the stored value.
    public var intendedRole: BallRole
    public var serialNumber: String
    public var colorDescription: String
    /// Month precision.
    public var releaseDate: Date?
    /// Not after today. Games since resurface never count games logged before it.
    public var purchaseDate: Date?
    public var factoryFinish: String
    /// Current surface. On add, empty starts from `factoryFinish`.
    public var surfaceGrit: String
    /// Nil means no resurface reminder; otherwise at least 1.
    public var resurfaceIntervalGames: Int?
    public var notes: String

    public init(
        name: String, brand: String = "", weightPounds: Int, coverstock: Coverstock = .unknown,
        coverstockName: String = "", coreType: CoreType = .unknown, coreName: String = "",
        rg: Double? = nil, differential: Double? = nil, intermediateDifferential: Double? = nil,
        intendedRole: BallRole = .strike, serialNumber: String = "", colorDescription: String = "",
        releaseDate: Date? = nil, purchaseDate: Date? = nil, factoryFinish: String = "",
        surfaceGrit: String = "", resurfaceIntervalGames: Int? = nil, notes: String = ""
    ) {
        self.name = name
        self.brand = brand
        self.weightPounds = weightPounds
        self.coverstock = coverstock
        self.coverstockName = coverstockName
        self.coreType = coreType
        self.coreName = coreName
        self.rg = rg
        self.differential = differential
        self.intermediateDifferential = intermediateDifferential
        self.intendedRole = intendedRole
        self.serialNumber = serialNumber
        self.colorDescription = colorDescription
        self.releaseDate = releaseDate
        self.purchaseDate = purchaseDate
        self.factoryFinish = factoryFinish
        self.surfaceGrit = surfaceGrit
        self.resurfaceIntervalGames = resurfaceIntervalGames
        self.notes = notes
    }
}

/// The ball detail screen's header and specs, and the edit form's starting values.
/// Wear and the log come from `maintenance(for:)`, the photo bytes from `photo(for:)`.
public struct BallDetail: Sendable, Hashable, Identifiable {
    public var id: BallID
    public var fields: BallFields
    public var isRetired: Bool
    public var hasPhoto: Bool
    /// Games with this ball as the default or on any roll, each game counted once.
    public var gamesBowled: Int
}

extension BallRepository {
    /// - Throws: `.notFound` for an unknown ball.
    public func detail(for ballID: BallID) throws -> BallDetail {
        try context.ball(ballID).detail()
    }

    /// The 1b form. The name is trimmed; an empty current surface starts from the factory
    /// finish.
    /// - Throws: `.invalidBall` for a field `updateBall` would refuse.
    public func addBall(_ fields: BallFields) throws -> BallDetail {
        let name = try validate(fields, checksPurchaseDate: true)
        return try context.write {
            let ball = Ball(name: name, weightPounds: fields.weightPounds)
            context.insert(ball)
            ball.apply(fields, name: name)
            if fields.surfaceGrit.isEmpty { ball.surfaceGrit = fields.factoryFinish }
            return ball.detail()
        }
    }

    /// Replaces every editable field. The name is trimmed. A coverstock or core type that
    /// reads as the stored one, including a newer version's value read as `.unknown`, keeps
    /// the stored string.
    /// - Throws: `.invalidBall(.emptyName)`, `.invalidBall(.weightOutOfRange)`,
    ///   `.invalidBall(.negativeSpec)` for a negative or non-finite RG or differential,
    ///   `.invalidBall(.resurfaceIntervalBelowOne)`, `.invalidBall(.purchaseDateInFuture)`
    ///   for a changed purchase date on a day after today, or `.notFound` for an unknown
    ///   ball. An unchanged purchase date is not checked: one saved "later today" on a
    ///   device further east reads as tomorrow here after sync, and must not lock the form.
    public func updateBall(_ ballID: BallID, with fields: BallFields) throws -> BallDetail {
        let ball = try context.ball(ballID)
        let name = try validate(fields, checksPurchaseDate: fields.purchaseDate != ball.purchaseDate)
        return try context.write {
            ball.apply(fields, name: name)
            ball.updatedAt = .now
            return ball.detail()
        }
    }

    /// The trimmed name, or the first field error.
    /// A purchase date later today is accepted: a date picker can store any time of day.
    private func validate(_ fields: BallFields, checksPurchaseDate: Bool) throws -> String {
        let name = fields.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw RepositoryError.invalidBall(.emptyName) }
        guard Self.weightRange.contains(fields.weightPounds) else { throw RepositoryError.invalidBall(.weightOutOfRange) }
        let specs = [fields.rg, fields.differential, fields.intermediateDifferential].compactMap(\.self)
        guard specs.allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw RepositoryError.invalidBall(.negativeSpec) }
        if let interval = fields.resurfaceIntervalGames, interval < 1 {
            throw RepositoryError.invalidBall(.resurfaceIntervalBelowOne)
        }
        if checksPurchaseDate, let purchase = fields.purchaseDate, calendar.startOfDay(for: purchase) > .now {
            throw RepositoryError.invalidBall(.purchaseDateInFuture)
        }
        return name
    }
}

extension Ball {
    func detail() -> BallDetail {
        BallDetail(id: id, fields: fields(), isRetired: isRetired, hasPhoto: photo != nil, gamesBowled: gamesBowled)
    }

    private func fields() -> BallFields {
        BallFields(
            name: name, brand: brand, weightPounds: weightPounds,
            coverstock: coverstockValue, coverstockName: coverstockName,
            coreType: coreTypeValue, coreName: coreName,
            rg: rg, differential: differential, intermediateDifferential: intermediateDifferential,
            intendedRole: BallRole(storedValue: intendedRole), serialNumber: serialNumber,
            colorDescription: colorDescription, releaseDate: releaseDate, purchaseDate: purchaseDate,
            factoryFinish: factoryFinish, surfaceGrit: surfaceGrit,
            resurfaceIntervalGames: resurfaceIntervalGames, notes: notes
        )
    }

    fileprivate func apply(_ fields: BallFields, name: String) {
        self.name = name
        brand = fields.brand
        weightPounds = fields.weightPounds
        if coverstockValue != fields.coverstock { coverstockValue = fields.coverstock }
        coverstockName = fields.coverstockName
        if coreTypeValue != fields.coreType { coreTypeValue = fields.coreType }
        coreName = fields.coreName
        rg = fields.rg
        differential = fields.differential
        intermediateDifferential = fields.intermediateDifferential
        if fields.intendedRole != .unknown { intendedRole = fields.intendedRole.rawValue }
        serialNumber = fields.serialNumber
        colorDescription = fields.colorDescription
        releaseDate = fields.releaseDate
        purchaseDate = fields.purchaseDate
        factoryFinish = fields.factoryFinish
        surfaceGrit = fields.surfaceGrit
        resurfaceIntervalGames = fields.resurfaceIntervalGames
        notes = fields.notes
    }
}
