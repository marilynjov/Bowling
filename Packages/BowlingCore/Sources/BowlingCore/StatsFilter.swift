import Foundation

/// The 1a date presets (spec section 6 "Filters"). Raw values are persisted with a saved filter.
public enum DatePreset: String, Sendable, Hashable, Codable, CaseIterable {
    case thisWeek, thisMonth, last30Days, thisSeason, allTime
}

/// Which games Stats is computed from (spec §6 "Filters"). The repository applies it;
/// `StatsEngine` only carries it on the report for labeling. A nil ball, pattern, center,
/// or league means any; the fields combine with AND.
public struct StatsFilter: Sendable, Hashable, Codable {
    public var datePreset: DatePreset
    /// "All games" is every case, `.unknown` included; "Competition" is `EventType.competition`.
    public var eventTypes: Set<EventType>
    /// Calendar days, both ends included. Replaces `datePreset` when set. Building a
    /// `ClosedRange` with start > end traps, so the date pickers clamp start <= end.
    public var customRange: ClosedRange<Date>?
    public var bowlerID: BowlerID
    /// Matches a game whose default ball or any roll override is this ball.
    public var ballID: BallID?
    public var oilPatternID: OilPatternID?
    public var centerID: CenterID?
    /// Also gives `thisSeason` the league's season dates.
    public var leagueID: LeagueID?

    public init(
        datePreset: DatePreset = .allTime, eventTypes: Set<EventType> = Set(EventType.allCases),
        customRange: ClosedRange<Date>? = nil, bowlerID: BowlerID, ballID: BallID? = nil,
        oilPatternID: OilPatternID? = nil, centerID: CenterID? = nil, leagueID: LeagueID? = nil
    ) {
        self.datePreset = datePreset
        self.eventTypes = eventTypes
        self.customRange = customRange
        self.bowlerID = bowlerID
        self.ballID = ballID
        self.oilPatternID = oilPatternID
        self.centerID = centerID
        self.leagueID = leagueID
    }

    /// Resolves the dates by calendar day in `calendar`'s time zone, with `thisSeason` as
    /// the last nine months.
    /// - Returns: A half-open interval, `start <= date < end`, or nil for all time.
    public func dateInterval(now: Date, calendar: Calendar) -> DateInterval? {
        dateInterval(now: now, calendar: calendar, leagueSeason: nil)
    }

    /// - Parameter leagueSeason: `seasonStart` and `seasonEnd` of the `leagueID` league, when
    ///   both exist; nil without a league filter. `thisSeason` then covers those calendar
    ///   days, the end day included; otherwise it falls back to the last nine months. Other
    ///   presets and a custom range ignore it.
    public func dateInterval(now: Date, calendar: Calendar, leagueSeason: DateInterval?) -> DateInterval? {
        if let customRange {
            return Self.wholeDays(customRange.lowerBound, through: customRange.upperBound, in: calendar)
        }
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
                return Self.wholeDays(leagueSeason.start, through: leagueSeason.end, in: calendar)
            }
            return DateInterval(start: calendar.date(byAdding: .month, value: -9, to: today)!, end: tomorrow)
        }
    }

    private static func wholeDays(_ first: Date, through last: Date, in calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: first)
        let lastDay = calendar.startOfDay(for: last)
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: lastDay)!)
    }

    /// The in-memory form of the filter, for callers holding `GameRecord`s. Incomplete
    /// games match too; `StatsEngine` excludes them itself.
    /// - Parameter leagueSeason: As in `dateInterval(now:calendar:leagueSeason:)`.
    public func matches(_ game: GameRecord, now: Date, calendar: Calendar, leagueSeason: DateInterval? = nil) -> Bool {
        guard game.bowlerID == bowlerID, eventTypes.contains(game.eventType) else { return false }
        guard Self.matches(centerID, game.centerID), Self.matches(leagueID, game.leagueID),
              Self.matches(oilPatternID, game.oilPatternID) else { return false }
        if let ballID, game.defaultBallID != ballID,
           !game.frames.contains(where: { $0.rolls.contains { $0.ballID == ballID } }) {
            return false
        }
        guard let interval = dateInterval(now: now, calendar: calendar, leagueSeason: leagueSeason) else { return true }
        return interval.start <= game.sessionDate && game.sessionDate < interval.end
    }

    /// A nil selection matches any value, including none.
    private static func matches(_ selected: UUID?, _ value: UUID?) -> Bool {
        selected == nil || selected == value
    }
}
