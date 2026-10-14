import BowlingCore
import Foundation

/// A History row.
public struct SessionSummary: Sendable, Hashable, Identifiable {
    public var id: SessionID
    public var date: Date
    public var eventType: EventType
    public var centerName: String?
    public var leagueName: String?
    public var bowlerCount: Int
    /// Grouped by bowler, the owner first and then by name, each bowler's by `gameIndex`.
    public var games: [GameRecord]
    /// Every game is complete.
    public var isComplete: Bool
}

public struct SessionDetail: Sendable, Hashable, Identifiable {
    public var id: SessionID
    public var metadata: SessionMetadata
    /// The owner first, then by name.
    public var bowlers: [SessionBowler]
}

public struct SessionBowler: Sendable, Hashable {
    public var bowler: BowlerRecord
    /// Sorted by `gameIndex`.
    public var games: [GameRecord]
    /// Sum of the cached final scores, incomplete games included.
    public var seriesTotal: Int
}

public struct SessionMetadata: Sendable, Hashable {
    public var date: Date
    /// Writing `.unknown` keeps the stored value.
    public var eventType: EventType
    public var centerID: CenterID?
    /// Only meaningful for league sessions.
    public var leagueID: LeagueID?
    public var oilPatternID: OilPatternID?
    public var lanes: String
    public var notes: String

    public init(
        date: Date, eventType: EventType, centerID: CenterID? = nil, leagueID: LeagueID? = nil,
        oilPatternID: OilPatternID? = nil, lanes: String = "", notes: String = ""
    ) {
        self.date = date
        self.eventType = eventType
        self.centerID = centerID
        self.leagueID = leagueID
        self.oilPatternID = oilPatternID
        self.lanes = lanes
        self.notes = notes
    }
}

/// A row of the center, league, or oil pattern picker.
public struct NamedRef: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
}
