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

    var header: Header
    /// Only the values that are set; the section hides when empty.
    var specs: [SpecRow]
    var maintenance: Maintenance

    init(fields: BallFields, isRetired: Bool, report: BallReport, recentGames: [GameRecord],
         filterChips: [String], centerNames: [CenterID: String], patternNames: [OilPatternID: String],
         calendar: Calendar = .current, locale: Locale = .current) {
        let format = Format(calendar: calendar, locale: locale)
        header = Self.header(fields, isRetired: isRetired)
        specs = Self.specs(fields, format)
        maintenance = Self.maintenance(report.maintenance, format)
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
