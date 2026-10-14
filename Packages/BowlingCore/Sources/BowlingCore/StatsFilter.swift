public enum DatePreset: String, Sendable, Hashable, Codable, CaseIterable {
    case thisWeek, thisMonth, last30Days, thisSeason, allTime
}

/// What the Stats screen is showing (spec §6 "Filters"). The repository applies it;
/// `StatsEngine` only carries it on the report for labeling.
public struct StatsFilter: Sendable, Hashable, Codable {
    public var datePreset: DatePreset
    public var eventTypes: Set<EventType>
    public var bowlerID: BowlerID

    public init(datePreset: DatePreset, eventTypes: Set<EventType>, bowlerID: BowlerID) {
        self.datePreset = datePreset
        self.eventTypes = eventTypes
        self.bowlerID = bowlerID
    }
}
