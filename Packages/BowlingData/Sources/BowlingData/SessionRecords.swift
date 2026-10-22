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
    /// Grouped by bowler in lineup order, each bowler's by `gameIndex`.
    public var games: [GameRecord]
    /// Every game is complete.
    public var isComplete: Bool
}

public struct SessionDetail: Sendable, Hashable, Identifiable {
    public var id: SessionID
    public var metadata: SessionMetadata
    /// Lineup order, the order given to `startSession`.
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

/// A league with what the app needs beyond the picker: the center for filtering the
/// New session picker, the season chip, and the high series length.
public struct LeagueRecord: Sendable, Hashable, Identifiable {
    public var id: LeagueID
    public var name: String
    public var centerID: CenterID?
    /// Free text such as "2026-27", empty when not set.
    public var seasonLabel: String
    /// Either date can be missing; the season is only usable when both are set.
    public var seasonStart: Date?
    public var seasonEnd: Date?
    public var gamesPerSession: Int
}
