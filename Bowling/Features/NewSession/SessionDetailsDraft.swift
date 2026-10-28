import BowlingCore
import BowlingData
import Foundation

/// A session's editable details: when, where, and on what. Shared by the new-session form
/// and the edit-details form so both follow the same rules.
struct SessionDetailsDraft: Hashable {
    var date: Date
    var eventType: EventType
    /// Changing it clears the league, which belongs to one center.
    var centerID: CenterID? {
        didSet { if centerID != oldValue { leagueID = nil } }
    }
    /// Saved only for league sessions; see `metadata`.
    var leagueID: LeagueID?
    var oilPatternID: OilPatternID?
    var lanes = ""
    var notes = ""

    init(date: Date, eventType: EventType) {
        self.date = date
        self.eventType = eventType
    }

    /// Starts from a saved session's details; the league is kept.
    init(_ metadata: SessionMetadata) {
        date = metadata.date
        eventType = metadata.eventType
        centerID = metadata.centerID
        leagueID = metadata.leagueID
        oilPatternID = metadata.oilPatternID
        lanes = metadata.lanes
        notes = metadata.notes
    }

    var metadata: SessionMetadata {
        SessionMetadata(
            date: date, eventType: eventType, centerID: centerID,
            leagueID: eventType == .league ? leagueID : nil,
            oilPatternID: oilPatternID, lanes: lanes, notes: notes
        )
    }

    /// The league picker's rows: the picked center's leagues, or the leagues with no center
    /// when none is picked. Add "<name>" checks only these, so a name can repeat at
    /// another center.
    func leagues(from records: [LeagueRecord]) -> [LeagueRecord] {
        records.filter { $0.centerID == centerID }
    }
}
