import BowlingCore
import Foundation

/// One spare attempt in the occurrence list, as text.
struct LeaveOccurrenceRow: Hashable, Identifiable {
    var id: LeaveOccurrence.ID
    var gameID: GameID
    var sessionID: SessionID?
    /// "Oct 14".
    var date: String
    /// History's line for the session, "League · AMF Bowl · Tuesday Mixed"; empty when the
    /// session isn't found.
    var session: String
    /// "Game 2 · Frame 7 · Phaze II".
    var position: String
    var isConverted: Bool
    /// "Made" / "Missed".
    var result: String
    var accessibilityLabel: String
}

/// Turns a leave's occurrences into the occurrence list's rows (spec §6 "Leave occurrences").
enum LeaveOccurrenceRows {
    /// - Parameters:
    ///   - sessions: Each session's History line, by ID.
    ///   - balls: Active and retired balls' names, by ID; a ball missing here (only from
    ///     sync) reads "Unknown ball".
    static func make(_ occurrences: [LeaveOccurrence], sessions: [SessionID: String], balls: [BallID: String],
                     calendar: Calendar = .current, locale: Locale = .current) -> [LeaveOccurrenceRow] {
        occurrences.map { occurrence in
            let date = day(occurrence.game.date, calendar, locale)
            let session = occurrence.game.sessionID.flatMap { sessions[$0] } ?? ""
            let ball = occurrence.ballID.map { balls[$0] ?? String(localized: "Unknown ball") }
                ?? String(localized: "No ball")
            let game = occurrence.gameIndex, frame = occurrence.frameIndex
            return LeaveOccurrenceRow(
                id: occurrence.id, gameID: occurrence.game.gameID, sessionID: occurrence.game.sessionID,
                date: date, session: session,
                position: String(localized: "Game \(game) · Frame \(frame)") + " · " + ball,
                isConverted: occurrence.isConverted,
                result: occurrence.isConverted ? String(localized: "Made") : String(localized: "Missed"),
                accessibilityLabel: AccessibilityText.leaveOccurrence(
                    date: date, session: session, game: game, frame: frame, ball: ball, made: occurrence.isConverted
                )
            )
        }
    }

    /// "Made 7 of 9 · 78%", over the listed attempts.
    static func summary(_ occurrences: [LeaveOccurrence], locale: Locale = .current) -> String {
        let made = occurrences.count(where: \.isConverted)
        let rate = StatFormat.percent(Rate(hits: made, attempts: occurrences.count), locale: locale)
        return String(localized: "Made \(made) of \(occurrences.count)") + " · " + rate
    }

    private static func day(_ date: Date, _ calendar: Calendar, _ locale: Locale) -> String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(locale)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}
