import BowlingCore
import Foundation
import SwiftData

// §3.2 MaintenanceEvent and its derived values, for the ball detail's Maintenance section
// and the Arsenal list's "Resurface due" badge.
extension BallRepository {
    /// Wear and the maintenance log, over every game the ball was used in, whatever the
    /// stats filter.
    /// - Throws: `.notFound` for an unknown ball.
    public func maintenance(for ballID: BallID) throws -> BallMaintenance {
        let ball = try context.ball(ballID)
        return BallMaintenance(
            ball: ballID, games: ball.gamesUsing.map { $0.record() },
            events: (ball.maintenance ?? []).map { $0.record() },
            resurfaceIntervalGames: ball.resurfaceIntervalGames
        )
    }

    /// Logs an event with a snapshot of the games bowled up to `date` (session date on or
    /// before it, as `GameConversion` dates a game), so a back-dated event matches when it
    /// happened. A non-empty grit becomes the ball's current surface.
    /// - Throws: `.notFound` for an unknown ball.
    public func logMaintenance(
        _ kind: MaintenanceKind, date: Date, surfaceGritAfter: String, notes: String, for ballID: BallID
    ) throws -> MaintenanceRecord {
        try context.write {
            let ball = try context.ball(ballID)
            let event = MaintenanceEvent(date: date, kind: MaintenanceEvent.Kind(stored: kind.rawValue))
            event.surfaceGritAfter = surfaceGritAfter
            event.gamesOnBallAtTime = ball.gamesUsing.count { ($0.session?.date ?? $0.createdAt) <= date }
            event.notes = notes
            context.insert(event)
            event.ball = ball
            if !surfaceGritAfter.isEmpty {
                ball.surfaceGrit = surfaceGritAfter
                ball.updatedAt = .now
            }
            return event.record()
        }
    }
}

extension Ball {
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
    func record() -> MaintenanceRecord {
        MaintenanceRecord(
            id: id, date: date, kind: MaintenanceKind(storedValue: kind),
            surfaceGritAfter: surfaceGritAfter, gamesOnBallAtTime: gamesOnBallAtTime, notes: notes
        )
    }
}
