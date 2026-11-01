import BowlingCore
import Foundation

/// One Stats card's title and what it shows.
struct StatsCard: Hashable, Identifiable {
    enum Body: Hashable {
        /// A single number; the footnote is the Average's "Last 10 201 · Last 30 195".
        case tile(StatTileContent, footnote: String?)
        case trend(TrendContent)
        /// Every row in report order; the view shows ten and "Show all".
        case leaves([LeaveRowContent])
        /// Nil when no leave was seen 3 times and missed.
        case leftMost(LeaveRowContent?)
        /// The card's games don't apply: the text says what to enter.
        case notApplicable(String)
        /// A 1b card whose view lands with #35.
        case comingSoon
    }

    var id: StatsCardID
    var title: String
    var body: Body
}

struct TrendContent: Hashable {
    /// Only points with a session average, ascending date.
    var points: [TrendPoint]
    /// "12 sessions" / "1 session".
    var sample: String
    var accessibilityLabel: String
}

struct LeaveRowContent: Hashable {
    var leave: Leave
    /// "Made 7 of 9".
    var made: String
    var rate: String
    var accessibilityLabel: String
}

/// Turns card IDs and a report into the Stats screen's cards (spec §3).
enum StatsCards {
    /// One card per ID, in order. A card whose games group is empty explains what to enter.
    static func make(cards: [StatsCardID], report: StatsReport, calendar: Calendar = .current) -> [StatsCard] {
        cards.map { StatsCard(id: $0, title: title($0), body: body($0, report, calendar)) }
    }

    private enum Group { case score, roll, pin }

    private static func group(_ card: StatsCardID) -> Group? {
        switch card {
        case .average, .highGame, .highSeries, .trendChart: .score
        case .strikePct, .sparePct, .fouls, .openPct, .cleanGamePct, .firstBallAverage: .roll
        case .headPinRate, .leavesTable, .leftMostMadeLeast, .splitConversion, .makeableConversion,
             .singlePinConversion: .pin
        case .byFrameStrike, .byFrameAverage, .whatIfSinglePins: nil
        }
    }

    private static func body(_ card: StatsCardID, _ report: StatsReport, _ calendar: Calendar) -> StatsCard.Body {
        guard let group = group(card) else { return .comingSoon }
        switch group {
        case .score where report.scoreGames == 0:
            return .notApplicable(String(localized: "No complete games yet."))
        case .roll where report.rollGames == 0:
            return .notApplicable(String(localized: "Enter frames to see strikes and spares."))
        case .pin where report.pinGames == 0:
            return .notApplicable(String(localized: "Enter pins to see leaves."))
        default:
            break
        }
        switch card {
        case .trendChart:
            return .trend(trend(report))
        case .leavesTable:
            return .leaves(report.leaves.map(row))
        case .leftMostMadeLeast:
            return .leftMost(report.leftMostMadeLeast.map(row))
        default:
            guard var tile = StatTileContent.make(card, report) else { return .comingSoon }
            switch card {
            case .average:
                return .tile(tile, footnote: averageFootnote(report))
            case .highGame:
                if let high = report.highGame { tile.sample = day(high.game.date, calendar) }
            case .highSeries:
                if let series = StatTileContent.threeGameSeries(report) { tile.sample = day(series.date, calendar) }
            default:
                break
            }
            return .tile(tile, footnote: nil)
        }
    }

    private static func title(_ card: StatsCardID) -> String {
        switch card {
        case .trendChart: String(localized: "Trend")
        case .leavesTable: String(localized: "Leaves")
        case .leftMostMadeLeast: String(localized: "Left most, made least")
        case .byFrameStrike: String(localized: "Strikes by frame")
        case .byFrameAverage: String(localized: "Average by frame")
        case .whatIfSinglePins: String(localized: "What if")
        default: StatTileContent.make(card, emptyReport)?.title ?? card.rawValue
        }
    }

    /// Titles don't depend on the numbers; this report only lets `StatTileContent` name a card.
    private static let emptyReport = StatsEngine.report(games: [], filter: StatsFilter(bowlerID: BowlerID()))

    /// "Last 10 201 · Last 30 195", each part only once there are more games than it covers.
    private static func averageFootnote(_ report: StatsReport) -> String? {
        var parts: [String] = []
        if report.average.count > 10 {
            parts.append(String(localized: "Last 10 \(StatFormat.average(report.averageLast10))"))
        }
        if report.average.count > 30 {
            parts.append(String(localized: "Last 30 \(StatFormat.average(report.averageLast30))"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func trend(_ report: StatsReport) -> TrendContent {
        let points = report.trend.filter { $0.sessionAverage.count > 0 }
        let sample = points.count == 1 ? String(localized: "1 session") : String(localized: "\(points.count) sessions")
        let latest = points.last
        return TrendContent(
            points: points, sample: sample,
            accessibilityLabel: AccessibilityText.trend(
                sessions: points.count,
                latest: latest.map { StatFormat.average($0.sessionAverage) } ?? "–",
                rolling: latest.map { StatFormat.average($0.rollingAverage) } ?? "–"
            )
        )
    }

    private static func row(_ row: LeaveRow) -> LeaveRowContent {
        let made = row.conversion.hits, count = row.conversion.attempts
        return LeaveRowContent(
            leave: row.leave, made: String(localized: "Made \(made) of \(count)"),
            rate: StatFormat.percent(row.conversion),
            accessibilityLabel: AccessibilityText.leaveRow(row.leave, made: made, of: count)
        )
    }

    private static func day(_ date: Date, _ calendar: Calendar) -> String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}
