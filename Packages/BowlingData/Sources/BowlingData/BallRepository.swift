import BowlingCore
import Foundation
import SwiftData

/// A row of the Arsenal list and the ball picker.
public struct BallSummary: Sendable, Hashable, Identifiable {
    public var id: BallID
    public var name: String
    public var brand: String
    public var weightPounds: Int
    public var intendedRole: BallRole
    /// Games with this ball as the default or on any roll, each game counted once.
    public var gamesBowled: Int
    public var isRetired: Bool
    /// The row shows the photo from `photo(for:)` or a placeholder.
    public var hasPhoto: Bool
    /// `BallMaintenance.isResurfaceDue`: the Arsenal list's "Resurface due" badge.
    public var isResurfaceDue: Bool
}

@MainActor
public final class BallRepository {
    static let weightRange = 6...16

    let context: ModelContext
    /// Finds the start of the purchase day for games since resurface and the future
    /// purchase check. Autoupdating, so a long-lived repository follows the device's time
    /// zone after travel. Tests set a fixed time zone.
    var calendar: Calendar = .autoupdatingCurrent

    init(context: ModelContext) {
        self.context = context
    }

    /// Balls not retired, by name.
    public func activeBalls() -> [BallSummary] {
        let descriptor = FetchDescriptor<Ball>(predicate: #Predicate { !$0.isRetired })
        let active = (try? context.fetch(descriptor)) ?? []
        return active
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { $0.summary(calendar: calendar) }
    }

    /// Retired balls, by name: the Arsenal list's collapsed Retired group.
    public func retiredBalls() -> [BallSummary] {
        let descriptor = FetchDescriptor<Ball>(predicate: #Predicate { $0.isRetired })
        let retired = (try? context.fetch(descriptor)) ?? []
        return retired
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { $0.summary(calendar: calendar) }
    }

    /// A retired ball keeps its games, stats, and log but leaves `activeBalls()`, so the
    /// pickers stop offering it. Games that already use it are unchanged.
    /// - Throws: `.notFound` for an unknown ball.
    public func setRetired(_ isRetired: Bool, for ballID: BallID) throws {
        try context.write {
            let ball = try context.ball(ballID)
            guard ball.isRetired != isRetired else { return }
            ball.isRetired = isRetired
            ball.updatedAt = .now
        }
    }

    /// Also deletes the ball's photo and maintenance log. A roll's nil ball means the game's
    /// default ball, so deleting a ball still on a roll would move that roll to the default.
    /// - Throws: `.ballHasGames(count:)` when any game uses the ball as its default or on a
    ///   roll override, so the user can retire it instead; `.notFound` for an unknown ball.
    public func deleteBall(_ ballID: BallID) throws {
        let ball = try context.ball(ballID)
        let gameCount = ball.gamesBowled
        guard gameCount == 0 else { throw RepositoryError.ballHasGames(count: gameCount) }
        try context.write { context.delete(ball) }
    }

    /// The 1a Arsenal form: name, weight, intended role, and brand.
    /// - Throws: `.invalidBall(.emptyName)` or `.invalidBall(.weightOutOfRange)`.
    public func addBall(name: String, weightPounds: Int, intendedRole: BallRole, brand: String) throws -> BallSummary {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw RepositoryError.invalidBall(.emptyName) }
        guard Self.weightRange.contains(weightPounds) else { throw RepositoryError.invalidBall(.weightOutOfRange) }

        return try context.write {
            let ball = Ball(name: trimmedName, weightPounds: weightPounds)
            ball.brand = brand
            if intendedRole != .unknown { ball.intendedRole = intendedRole.rawValue }
            context.insert(ball)
            return ball.summary(calendar: calendar)
        }
    }
}

extension Ball {
    func summary(calendar: Calendar) -> BallSummary {
        BallSummary(
            id: id,
            name: name,
            brand: brand,
            weightPounds: weightPounds,
            intendedRole: BallRole(storedValue: intendedRole),
            gamesBowled: gamesBowled,
            isRetired: isRetired,
            hasPhoto: photo != nil,
            isResurfaceDue: isResurfaceDue(calendar: calendar)
        )
    }

    var gamesBowled: Int {
        let defaultGames = (gamesAsDefault ?? []).map(\.persistentModelID)
        let overrideGames = (rollsAsOverride ?? []).compactMap { $0.frame?.game?.persistentModelID }
        return Set(defaultGames + overrideGames).count
    }
}
