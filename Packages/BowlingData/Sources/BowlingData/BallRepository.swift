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
}

@MainActor
public final class BallRepository {
    static let weightRange = 6...16

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Balls not retired, by name.
    public func activeBalls() -> [BallSummary] {
        let descriptor = FetchDescriptor<Ball>(predicate: #Predicate { !$0.isRetired })
        let active = (try? context.fetch(descriptor)) ?? []
        return active
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { $0.summary() }
    }

    /// The 1a Arsenal form: name, weight, intended role, and brand.
    /// - Throws: `.invalidBall(.emptyName)` or `.invalidBall(.weightOutOfRange)`.
    public func addBall(name: String, weightPounds: Int, intendedRole: BallRole, brand: String) throws -> BallSummary {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw RepositoryError.invalidBall(.emptyName) }
        guard Self.weightRange.contains(weightPounds) else { throw RepositoryError.invalidBall(.weightOutOfRange) }

        let ball = Ball(name: trimmedName, weightPounds: weightPounds)
        ball.brand = brand
        if intendedRole != .unknown { ball.intendedRole = intendedRole.rawValue }
        context.insert(ball)
        try context.commit()
        return ball.summary()
    }
}

extension Ball {
    func summary() -> BallSummary {
        BallSummary(
            id: id,
            name: name,
            brand: brand,
            weightPounds: weightPounds,
            intendedRole: BallRole(storedValue: intendedRole),
            gamesBowled: gamesBowled
        )
    }

    var gamesBowled: Int {
        let defaultGames = (gamesAsDefault ?? []).map(\.persistentModelID)
        let overrideGames = (rollsAsOverride ?? []).compactMap { $0.frame?.game?.persistentModelID }
        return Set(defaultGames + overrideGames).count
    }
}
