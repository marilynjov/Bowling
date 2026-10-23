import Foundation

public typealias MaintenanceEventID = UUID

/// Stored raw values of `MaintenanceEvent.kind` (§3.2). Only `.resurface` resets the
/// games-since-resurface count.
public enum MaintenanceKind: String, Sendable, Hashable, Codable, CaseIterable {
    case resurface, polish, oilExtraction, plugAndRedrill, other
    case unknown

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .unknown
    }

    public init(from decoder: any Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}

/// One entry of a ball's maintenance log (§3.2 MaintenanceEvent).
public struct MaintenanceRecord: Sendable, Hashable, Codable, Identifiable {
    public var id: MaintenanceEventID
    public var date: Date
    public var kind: MaintenanceKind
    public var surfaceGritAfter: String
    /// Games bowled on the ball when the event was logged.
    public var gamesOnBallAtTime: Int
    public var notes: String

    public init(
        id: MaintenanceEventID = MaintenanceEventID(), date: Date, kind: MaintenanceKind,
        surfaceGritAfter: String = "", gamesOnBallAtTime: Int = 0, notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.surfaceGritAfter = surfaceGritAfter
        self.gamesOnBallAtTime = gamesOnBallAtTime
        self.notes = notes
    }
}

/// A ball's wear and its maintenance log (§3.2 MaintenanceEvent "Derived values").
///
/// Wear is physical, so every game counts, incomplete ones included, and the games passed
/// should be all of the ball's games rather than a stats filter's selection.
public struct BallMaintenance: Sendable, Hashable {
    /// Games with the ball as the default or on any roll override, each counted once.
    public var gamesBowled: Int
    /// Games bowled after the latest resurface; without one, games since purchase, or every
    /// game bowled when the purchase date is not set either.
    public var gamesSinceResurface: Int
    /// Date of the latest resurface; nil when the ball has never been resurfaced.
    public var lastResurface: Date?
    public var resurfaceIntervalGames: Int?
    /// Newest first.
    public var events: [MaintenanceRecord]

    /// The interval is set and games since the last resurface meet or exceed it.
    public var isResurfaceDue: Bool {
        resurfaceIntervalGames.map { gamesSinceResurface >= $0 } ?? false
    }

    /// A game played at the very instant of a resurface counts as before it: the bowler
    /// logs the resurface when the ball comes back from the shop, ahead of the next game.
    /// A game at or after `purchaseDate` counts as after the purchase; pass the start of the
    /// purchase day so that day's games count whatever time the date picker stored.
    public init(
        ball: BallID, games: [GameRecord], events: [MaintenanceRecord], resurfaceIntervalGames: Int?,
        purchaseDate: Date? = nil
    ) {
        let used = games.filter { $0.uses(ball) }
        let resurface = events.filter { $0.kind == .resurface }.map(\.date).max()
        gamesBowled = used.count
        gamesSinceResurface = if let resurface {
            used.count { $0.sessionDate > resurface }
        } else if let purchaseDate {
            used.count { $0.sessionDate >= purchaseDate }
        } else {
            used.count
        }
        lastResurface = resurface
        self.resurfaceIntervalGames = resurfaceIntervalGames
        self.events = events.sorted { $0.date > $1.date }
    }
}

extension GameRecord {
    /// The game's default ball, or any roll's override, is `ball` (§3.2 "Games bowled",
    /// §6 ball filter).
    public func uses(_ ball: BallID) -> Bool {
        defaultBallID == ball || frames.contains { $0.rolls.contains { $0.ballID == ball } }
    }
}
