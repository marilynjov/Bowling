import BowlingCore
import Foundation
import SwiftData

// §3.2 MaintenanceEvent and its derived values, for the ball detail's Maintenance section
// and the Arsenal list's "Resurface due" badge.
extension BallRepository {
    /// Wear and the maintenance log, over every game the ball was used in, whatever the
    /// stats filter. Games since resurface count from the latest resurface; only when none
    /// is logged, from the start of the purchase day in the repository's calendar.
    /// - Throws: `.notFound` for an unknown ball.
    public func maintenance(for ballID: BallID) throws -> BallMaintenance {
        try context.ball(ballID).wear(calendar: calendar)
    }

    /// Logs an event with a snapshot of the games bowled up to `date` (session date on or
    /// before it, by `Game.sessionDate`), so a back-dated event matches when it
    /// happened. `date` is a full timestamp, now by default. A non-empty grit becomes the
    /// ball's current surface unless another event with a grit is dated later.
    /// - Throws: `.invalidMaintenance(.dateInFuture)` for a date after now,
    ///   `.invalidMaintenance(.unknownKind)` for `.unknown`, `.notFound` for an unknown ball.
    public func logMaintenance(
        _ kind: MaintenanceKind, date: Date = .now, surfaceGritAfter: String, notes: String, for ballID: BallID
    ) throws -> MaintenanceRecord {
        guard date <= .now else { throw RepositoryError.invalidMaintenance(.dateInFuture) }
        guard kind != .unknown else { throw RepositoryError.invalidMaintenance(.unknownKind) }
        return try context.write {
            let ball = try context.ball(ballID)
            let isLatestGrit = (ball.maintenance ?? []).allSatisfy { $0.surfaceGritAfter.isEmpty || $0.date <= date }
            let event = MaintenanceEvent(date: date, kind: MaintenanceEvent.Kind(stored: kind.rawValue))
            event.surfaceGritAfter = surfaceGritAfter
            event.gamesOnBallAtTime = ball.gamesUsing.count { $0.sessionDate <= date }
            event.notes = notes
            context.insert(event)
            event.ball = ball
            if !surfaceGritAfter.isEmpty && isLatestGrit {
                ball.surfaceGrit = surfaceGritAfter
                ball.updatedAt = .now
            }
            return event.record()
        }
    }
}

extension Ball {
    func wear(calendar: Calendar) -> BallMaintenance {
        BallMaintenance(
            ball: id, games: gamesUsing.map { $0.record() },
            events: (maintenance ?? []).map { $0.record() },
            resurfaceIntervalGames: resurfaceIntervalGames,
            purchaseDate: purchaseDate.map(calendar.startOfDay)
        )
    }

    /// `wear(calendar:).isResurfaceDue` from session dates alone: `activeBalls()` runs it for
    /// every ball on Scoring and New session, so it skips converting games to records.
    /// `games` is `gamesUsing`, passed in so the caller walks the relationships once.
    func isResurfaceDue(games: [Game], calendar: Calendar) -> Bool {
        guard let interval = resurfaceIntervalGames else { return false }
        let lastResurface = (maintenance ?? [])
            .filter { $0.kindRecord == .resurface }
            .map(\.date).max()
        let count = BallMaintenance.gamesSinceResurface(
            sessionDates: games.map(\.sessionDate),
            lastResurface: lastResurface, purchaseDate: purchaseDate.map(calendar.startOfDay)
        )
        return count >= interval
    }

    /// Games with this ball as the default or on any roll, each once.
    var gamesUsing: [Game] {
        let overrideGames = (rollsAsOverride ?? []).compactMap { $0.frame?.game }
        var seen = Set<PersistentIdentifier>()
        return ((gamesAsDefault ?? []) + overrideGames).filter { seen.insert($0.persistentModelID).inserted }
    }
}

extension MaintenanceEvent {
    /// Reads the stored kind straight into `MaintenanceKind`, so a kind from a newer app
    /// version reads as `.unknown` instead of the model enum's `.other`.
    var kindRecord: MaintenanceKind {
        MaintenanceKind(storedValue: kind)
    }

    func record() -> MaintenanceRecord {
        MaintenanceRecord(
            id: id, date: date, kind: kindRecord,
            surfaceGritAfter: surfaceGritAfter, gamesOnBallAtTime: gamesOnBallAtTime, notes: notes
        )
    }
}
