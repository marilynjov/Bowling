import BowlingCore
import BowlingData
import Foundation

/// The ball detail screen's text (spec §7 "Ball detail"). The builder is pure, so the
/// mixed-ball fixture can be fed through `StatsEngine.ballReport` in tests; `load` reads
/// the same inputs from the store.
struct BallDetailData: Hashable {
    struct Header: Hashable {
        var name: String
        /// "Storm · 15 lb"; the brand is left out when blank.
        var subtitle: String
        /// "Reactive solid · Asymmetric"; nil when neither is set.
        var construction: String?
        /// Nil for a role written by a newer version.
        var role: String?
        var surface: String?
        var serial: String?
        var isRetired: Bool
    }

    struct SpecRow: Hashable {
        var label: String
        var value: String
    }

    struct LogRow: Hashable {
        var title: String
        var date: String
        /// "grit · notes", either part left out when blank; nil when both are.
        var detail: String?
    }

    struct Maintenance: Hashable {
        var summary: String
        /// 0...1 against the resurface interval; nil without one.
        var progress: Double?
        var isDue: Bool
        /// Newest first.
        var log: [LogRow]
    }

    struct PerformanceBlock: Hashable {
        var title: String
        var tiles: [StatTileContent]
        var sample: String
    }

    struct ConditionRowText: Hashable {
        var name: String
        var strikes: String
        var firstBallAverage: String
    }

    struct TrendPoint: Hashable {
        var date: Date
        /// 0...100.
        var percent: Double
    }

    struct Marker: Hashable {
        var date: Date
        var isResurface: Bool
    }

    struct Trend: Hashable {
        /// Oldest first.
        var points: [TrendPoint]
        /// Maintenance events inside the points' date range.
        var markers: [Marker]
        var accessibilityLabel: String
    }

    struct RecentGame: Hashable, Identifiable {
        var id: GameID
        var date: String
        var score: String
        var eventType: String
    }

    var header: Header
    /// The header shows the photo or the #28 placeholder.
    var hasPhoto: Bool
    /// Only the values that are set; the section hides when empty.
    var specs: [SpecRow]
    var maintenance: Maintenance
    /// The Stats filter's chips, read-only until #33.
    var chips: [String]
    /// Strike and spare blocks, the spare block first for a spare ball; empty when the
    /// ball has no games in the filter.
    var performance: [PerformanceBlock]
    var leaves: [LeaveRowContent]
    var byPattern: [ConditionRowText]
    var byCenter: [ConditionRowText]
    /// Nil with fewer than 2 sessions.
    var trend: Trend?
    /// In the order given: newest first.
    var recent: [RecentGame]

    init(fields: BallFields, isRetired: Bool, hasPhoto: Bool = false, report: BallReport, recentGames: [GameRecord],
         filterChips: [String], centerNames: [CenterID: String], patternNames: [OilPatternID: String],
         calendar: Calendar = .current, locale: Locale = .current) {
        let format = Format(calendar: calendar, locale: locale)
        header = Self.header(fields, isRetired: isRetired)
        self.hasPhoto = hasPhoto
        specs = Self.specs(fields, format)
        maintenance = Self.maintenance(report.maintenance, format)
        chips = filterChips
        performance = Self.performance(report, role: fields.intendedRole)
        leaves = report.leaves.map(LeaveRowContent.init)
        byPattern = Self.conditions(report.byOilPattern, names: patternNames)
        byCenter = Self.conditions(report.byCenter, names: centerNames)
        trend = Self.trend(report)
        recent = recentGames.map {
            RecentGame(id: $0.id, date: format.day($0.sessionDate), score: "\($0.finalScore)", eventType: $0.eventType.title)
        }
    }

    /// Reads the ball, its games under `filter`, and the names the screen shows.
    /// The filter's dates and event types apply, but always to the owner's games: balls are
    /// the owner's, so a friend in the Stats filter would empty every ball's page.
    /// - Throws: `.notFound` for an unknown ball.
    static func load(id: BallID, store: BowlingStore, filter: StatsFilterDraft, now: Date = .now,
                     calendar: Calendar = .current, locale: Locale = .current) throws -> BallDetailData {
        let detail = try store.balls.detail(for: id)
        var draft = filter
        if let owner = store.bowlers.owner() {
            draft.filter.bowlerID = owner.id
            draft.bowlerName = owner.name
        }
        let games = store.stats.games(matching: draft.filter, now: now, calendar: calendar)
        let report = StatsEngine.ballReport(for: id, games: games, maintenance: try store.balls.maintenance(for: id))
        let recent = games.filter { $0.isComplete && $0.uses(id) }.suffix(10).reversed()
        return BallDetailData(
            fields: detail.fields, isRetired: detail.isRetired, hasPhoto: detail.hasPhoto, report: report, recentGames: Array(recent),
            filterChips: draft.chips,
            centerNames: Dictionary(store.sessions.centers().map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a }),
            patternNames: Dictionary(store.sessions.oilPatterns().map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a }),
            calendar: calendar, locale: locale
        )
    }

    // MARK: Performance

    private static func performance(_ report: BallReport, role: BallRole) -> [PerformanceBlock] {
        guard report.gamesBowled > 0 else { return [] }
        let strike = PerformanceBlock(
            title: String(localized: "As a strike ball"),
            tiles: [
                .rate(String(localized: "Strikes"), report.strikes, .firstBalls),
                .mean(String(localized: "First ball average"), report.firstBallAverage, .firstBalls),
                .rate(String(localized: "Head pin"), report.headPin, .firstBalls),
                .mean(String(localized: "Average as main ball"), report.averageAsMainBall, .games),
            ],
            sample: StatFormat.sample(report.firstBalls, .firstBalls)
        )
        let spare = PerformanceBlock(
            title: String(localized: "As a spare ball"),
            tiles: [
                .rate(String(localized: "Spares"), report.spares, .spareAttempts),
                .rate(String(localized: "Single pins"), report.singlePinConversion, .spareAttempts),
                .rate(String(localized: "Splits"), report.splitConversion, .spareAttempts),
            ],
            sample: StatFormat.sample(report.spareAttempts, .spareAttempts)
        )
        return role == .spare ? [spare, strike] : [strike, spare]
    }

    /// Report order; a nil or unknown ID reads "Other".
    private static func conditions<ID: Hashable>(_ rows: [ConditionRow], names: [ID: String]) -> [ConditionRowText] {
        rows.map { row in
            ConditionRowText(
                name: (row.id as? ID).flatMap { names[$0] } ?? String(localized: "Other"),
                strikes: StatFormat.percent(row.strikes),
                firstBallAverage: StatFormat.average(row.firstBallAverage)
            )
        }
    }

    private static func trend(_ report: BallReport) -> Trend? {
        let points = report.overTime.compactMap { point in
            point.strikes.value.map { TrendPoint(date: point.date, percent: $0 * 100) }
        }
        guard points.count >= 2, let first = points.first?.date, let last = points.last?.date,
              let latest = report.overTime.last(where: { $0.strikes.value != nil })
        else { return nil }
        let markers = report.maintenance.events
            .filter { (first...last).contains($0.date) }
            .sorted { $0.date < $1.date }
            .map { Marker(date: $0.date, isResurface: $0.kind == .resurface) }
        return Trend(
            points: points, markers: markers,
            accessibilityLabel: String(localized: "Strike rate over \(points.count) sessions, latest \(StatFormat.percent(latest.strikes)).")
        )
    }

    // MARK: Header and specs

    private static func header(_ fields: BallFields, isRetired: Bool) -> Header {
        let construction = [
            fields.coverstock == .unknown ? nil : BallForm.title(for: fields.coverstock),
            fields.coreType == .unknown ? nil : BallForm.title(for: fields.coreType),
        ].compactMap { $0 }
        return Header(
            name: fields.name,
            subtitle: [nonBlank(fields.brand), String(localized: "\(fields.weightPounds) lb")]
                .compactMap { $0 }.joined(separator: " · "),
            construction: construction.isEmpty ? nil : construction.joined(separator: " · "),
            role: roleTitle(fields.intendedRole),
            surface: nonBlank(fields.surfaceGrit).map { String(localized: "Surface: \($0)") },
            serial: nonBlank(fields.serialNumber).map { String(localized: "Serial \($0)") },
            isRetired: isRetired
        )
    }

    static func roleTitle(_ role: BallRole) -> String? {
        switch role {
        case .strike: String(localized: "Strike ball")
        case .spare: String(localized: "Spare ball")
        case .both: String(localized: "Strike and spare")
        case .unknown: nil
        }
    }

    private static func specs(_ fields: BallFields, _ format: Format) -> [SpecRow] {
        let rows: [(String, String?)] = [
            (String(localized: "Coverstock name"), nonBlank(fields.coverstockName)),
            (String(localized: "Core name"), nonBlank(fields.coreName)),
            (String(localized: "RG"), fields.rg.map(format.number)),
            (String(localized: "Differential"), fields.differential.map(format.number)),
            (String(localized: "Intermediate differential"), fields.intermediateDifferential.map(format.number)),
            (String(localized: "Factory finish"), nonBlank(fields.factoryFinish)),
            (String(localized: "Release date"), fields.releaseDate.map(format.month)),
            (String(localized: "Purchase date"), fields.purchaseDate.map(format.day)),
            (String(localized: "Color"), nonBlank(fields.colorDescription)),
            (String(localized: "Notes"), nonBlank(fields.notes)),
        ]
        return rows.compactMap { label, value in value.map { SpecRow(label: label, value: $0) } }
    }

    // MARK: Maintenance

    private static func maintenance(_ m: BallMaintenance, _ format: Format) -> Maintenance {
        let since = m.gamesSinceResurface
        let summary: String
        var progress: Double?
        if let interval = m.resurfaceIntervalGames {
            summary = String(localized: "\(since) of \(interval) games since resurface")
            progress = min(1, Double(since) / Double(max(interval, 1)))
        } else if m.lastResurface != nil {
            summary = String(localized: "\(since) games since resurface")
        } else {
            summary = String(localized: "Never resurfaced · \(since) games")
        }
        let log = m.events.sorted { $0.date > $1.date }.map { event in
            let detail = [nonBlank(event.surfaceGritAfter), nonBlank(event.notes)].compactMap { $0 }
            return LogRow(title: kindTitle(event.kind), date: format.day(event.date),
                          detail: detail.isEmpty ? nil : detail.joined(separator: " · "))
        }
        return Maintenance(summary: summary, progress: progress, isDue: m.isResurfaceDue, log: log)
    }

    static func kindTitle(_ kind: MaintenanceKind) -> String {
        switch kind {
        case .resurface: String(localized: "Resurface")
        case .polish: String(localized: "Polish")
        case .oilExtraction: String(localized: "Oil extraction")
        case .plugAndRedrill: String(localized: "Plug and redrill")
        case .other, .unknown: String(localized: "Other")
        }
    }

    // MARK: Formatting

    private static func nonBlank(_ text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Dates and numbers in one calendar and locale; tests pass fixed ones.
    struct Format {
        var calendar: Calendar
        var locale: Locale

        func number(_ value: Double) -> String {
            value.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...3)))
        }

        func day(_ date: Date) -> String {
            date.formatted(style(.dateTime.month(.abbreviated).day().year()))
        }

        func month(_ date: Date) -> String {
            date.formatted(style(.dateTime.month(.wide).year()))
        }

        private func style(_ base: Date.FormatStyle) -> Date.FormatStyle {
            var style = base
            style.calendar = calendar
            style.timeZone = calendar.timeZone
            style.locale = locale
            return style
        }
    }
}
