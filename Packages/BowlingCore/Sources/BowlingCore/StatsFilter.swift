import Foundation

/// The 1a date presets (spec section 6 "Filters"). Raw values are persisted with a saved filter.
public enum DatePreset: String, Sendable, Hashable, Codable, CaseIterable {
    case thisWeek, thisMonth, last30Days, thisSeason, allTime
}

/// Which games Stats is computed from. 1a fields only; 1b adds a custom range, ball,
/// oil pattern, center, and league.
public struct StatsFilter: Sendable, Hashable, Codable {
    public var datePreset: DatePreset
    /// "All games" is every case, `.unknown` included; "Competition" is `EventType.competition`.
    public var eventTypes: Set<EventType>
    public var bowlerID: BowlerID

    public init(
        bowlerID: BowlerID, datePreset: DatePreset = .allTime,
        eventTypes: Set<EventType> = Set(EventType.allCases)
    ) {
        self.bowlerID = bowlerID
        self.datePreset = datePreset
        self.eventTypes = eventTypes
    }

    /// Resolves the preset by calendar day in `calendar`'s time zone. In 1a there is no
    /// league filter, so `thisSeason` is always the last nine months.
    /// - Returns: A half-open interval, `start <= date < end`, or nil for all time.
    public func dateInterval(now: Date, calendar: Calendar) -> DateInterval? {
        dateInterval(now: now, calendar: calendar, leagueSeason: nil)
    }

    /// - Parameter leagueSeason: The selected league's `seasonStart` and `seasonEnd`, when
    ///   both exist. `thisSeason` then covers those calendar days, the end day included;
    ///   otherwise it falls back to the last nine months. Other presets ignore it.
    public func dateInterval(now: Date, calendar: Calendar, leagueSeason: DateInterval?) -> DateInterval? {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        switch datePreset {
        case .allTime:
            return nil
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        case .last30Days:
            return DateInterval(start: calendar.date(byAdding: .day, value: -29, to: today)!, end: tomorrow)
        case .thisSeason:
            if let leagueSeason {
                let start = calendar.startOfDay(for: leagueSeason.start)
                let lastDay = calendar.startOfDay(for: leagueSeason.end)
                return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: lastDay)!)
            }
            return DateInterval(start: calendar.date(byAdding: .month, value: -9, to: today)!, end: tomorrow)
        }
    }

    /// The in-memory form of the filter, for callers holding `GameRecord`s. Incomplete
    /// games match too; `StatsEngine` excludes them itself.
    public func matches(_ game: GameRecord, now: Date, calendar: Calendar, leagueSeason: DateInterval? = nil) -> Bool {
        guard game.bowlerID == bowlerID, eventTypes.contains(game.eventType) else { return false }
        guard let interval = dateInterval(now: now, calendar: calendar, leagueSeason: leagueSeason) else { return true }
        return interval.start <= game.sessionDate && game.sessionDate < interval.end
    }
}
