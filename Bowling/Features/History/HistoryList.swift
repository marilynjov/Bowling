import BowlingCore
import BowlingData
import Foundation

/// One month of History, its sessions newest first.
struct HistoryMonth: Hashable, Identifiable {
    /// The first instant of the month.
    var id: Date
    /// "October 2026".
    var title: String
    var rows: [RecentRow]
}

enum HistoryList {
    /// Sessions grouped by calendar month, newest month first and newest session first
    /// inside each.
    static func months(from sessions: [SessionSummary], owner: BowlerID, calendar: Calendar = .current) -> [HistoryMonth] {
        let newestFirst = sessions.sorted { $0.date > $1.date }
        let groups = Dictionary(grouping: newestFirst) { calendar.dateInterval(of: .month, for: $0.date)!.start }
        return groups.keys.sorted(by: >).map { start in
            HistoryMonth(
                id: start,
                title: start.formatted(Date.FormatStyle(timeZone: calendar.timeZone).month(.wide).year()),
                rows: groups[start, default: []].map { RecentRow($0, owner: owner) }
            )
        }
    }
}
