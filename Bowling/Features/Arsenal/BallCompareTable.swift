import BowlingCore
import BowlingData
import Foundation

/// Arsenal's Compare (spec §7, Arsenal 1b): one row per active ball from
/// `StatsEngine.compareBalls`, each figure with its sample, sortable by any column.
struct BallCompareTable: Hashable {
    enum Column: String, CaseIterable, Hashable, Identifiable {
        case games, average, strikes, firstBall, spares

        var id: Self { self }

        var title: String {
            switch self {
            case .games: String(localized: "Games")
            case .average: String(localized: "Average")
            case .strikes: String(localized: "Strike %")
            case .firstBall: String(localized: "First ball")
            case .spares: String(localized: "Spare %")
            }
        }
    }

    struct Cell: Hashable {
        /// "196.5", "54%", "–" with no sample.
        var value: String
        /// "12", the games, first balls or spare attempts behind `value`; nil for Games.
        var sample: String?
        /// Nil sorts last whichever way the column sorts.
        var sortValue: Double?
    }

    struct Row: Hashable, Identifiable {
        var id: BallID
        var name: String
        var cells: [Column: Cell]
        var accessibilityLabel: String
    }

    enum SortKey: Hashable {
        case name
        case column(Column)
    }

    struct Sort: Hashable {
        var key: SortKey = .column(.average)
        var ascending = false

        /// Tapping the sorted column flips it; another column starts high to low, the
        /// name A to Z.
        func tapping(_ key: SortKey) -> Sort {
            key == self.key ? Sort(key: key, ascending: !ascending) : Sort(key: key, ascending: key == .name)
        }
    }

    var rows: [Row]
    /// The Stats filter as ball detail applies it, "All time", "Competition", "Sam".
    var chips: [String]

    /// Rows in `sort` order. A blank figure goes last either way; ties, and the name
    /// column, go A to Z by name.
    func sorted(by sort: Sort) -> [Row] {
        rows.sorted { a, b in
            let byName = a.name.localizedStandardCompare(b.name)
            guard case .column(let column) = sort.key else {
                return byName == (sort.ascending ? .orderedAscending : .orderedDescending)
            }
            switch (a.cells[column]?.sortValue, b.cells[column]?.sortValue) {
            case let (x?, y?) where x != y: return sort.ascending ? x < y : x > y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return byName == .orderedAscending
            }
        }
    }

    init(rows: [Row], chips: [String] = []) {
        self.rows = rows
        self.chips = chips
    }

    /// - Parameter names: The balls in `comparison`, by ID.
    init(_ comparison: [BallComparisonRow], names: [BallID: String], chips: [String] = [],
         locale: Locale = .current) {
        rows = comparison.map { row in
            let name = names[row.ballID] ?? ""
            let cells: [Column: Cell] = [
                .games: Cell(value: row.gamesBowled.formatted(.number.locale(locale)), sample: nil,
                             sortValue: Double(row.gamesBowled)),
                .average: Self.cell(row.averageAsMainBall, locale),
                .strikes: Self.cell(row.strikes, locale),
                .firstBall: Self.cell(row.firstBallAverage, locale),
                .spares: Self.cell(row.spares, locale),
            ]
            return Row(id: row.ballID, name: name, cells: cells,
                       accessibilityLabel: Self.accessibilityLabel(name: name, cells: cells))
        }
        self.chips = chips
    }

    /// Every active ball under `filter`, applied to the owner's games as on ball detail.
    static func load(store: BowlingStore, filter: StatsFilterDraft, now: Date = .now,
                     calendar: Calendar = .current, locale: Locale = .current) -> BallCompareTable {
        let draft = filter.forOwnersBalls(in: store)
        let balls = store.balls.activeBalls()
        let games = store.stats.games(matching: draft.filter, now: now, calendar: calendar)
        return BallCompareTable(
            StatsEngine.compareBalls(balls.map(\.id), games: games),
            names: Dictionary(balls.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a }),
            chips: draft.chips, locale: locale
        )
    }

    private static func cell(_ mean: Mean, _ locale: Locale) -> Cell {
        Cell(value: StatFormat.average(mean, locale: locale), sample: mean.count.formatted(.number.locale(locale)),
             sortValue: mean.value)
    }

    private static func cell(_ rate: Rate, _ locale: Locale) -> Cell {
        Cell(value: StatFormat.percent(rate, locale: locale), sample: rate.attempts.formatted(.number.locale(locale)),
             sortValue: rate.value)
    }

    /// "Phaze II, 12 games, average 196.5 over 10, strike % 54% over 120, ...". A blank
    /// figure reads "none".
    private static func accessibilityLabel(name: String, cells: [Column: Cell]) -> String {
        let figures = Column.allCases.compactMap { column -> String? in
            guard let cell = cells[column] else { return nil }
            guard column != .games else {
                return String(localized: "\(cell.value) games")
            }
            guard cell.sortValue != nil, let sample = cell.sample else {
                return String(localized: "\(column.title) none")
            }
            return String(localized: "\(column.title) \(cell.value) over \(sample)")
        }
        return ([name] + figures).joined(separator: ", ")
    }
}
