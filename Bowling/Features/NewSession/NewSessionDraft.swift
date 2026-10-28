import BowlingCore
import BowlingData
import Foundation
import SwiftUI

/// One bowler in the new session's lineup.
struct LineupEntry: Hashable, Identifiable {
    var bowlerID: BowlerID
    var name: String
    var isOwner: Bool
    /// The owner's only, until balls belong to a bowler.
    var ballID: BallID?
    var id: BowlerID { bowlerID }
}

/// The IDs a remembered value may point at: anything else was deleted or retired.
struct Available: Hashable {
    var centers: Set<CenterID>
    var leagues: Set<LeagueID>
    var oilPatterns: Set<OilPatternID>
    var balls: Set<BallID>

    static func current(in store: BowlingStore) -> Available {
        Available(
            centers: Set(store.sessions.centers().map(\.id)),
            leagues: Set(store.sessions.leagues().map(\.id)),
            oilPatterns: Set(store.sessions.oilPatterns().map(\.id)),
            balls: Set(store.balls.activeBalls().map(\.id))
        )
    }
}

/// What Add bowler shows.
struct AddBowlerChoices {
    /// Everyone not in the lineup (so never the owner).
    var candidates: [BowlerRecord]
    /// Every bowler's name, for the Add row.
    var names: [String]

    func addName(for text: String) -> String? {
        NameSearch.addName(for: text, existing: names)
    }
}

/// The new-session form's answers. Nothing is saved until `start`.
struct NewSessionDraft {
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
    var entryMode: EntryMode = .pinByPin
    /// Lineup order. The owner is always in it.
    var lineup: [LineupEntry]

    init(owner: BowlerRecord, date: Date, eventType: EventType = .practice) {
        self.date = date
        self.eventType = eventType
        lineup = [LineupEntry(bowlerID: owner.id, name: owner.name, isOwner: true)]
    }

    /// Appends `bowler` unless they're already in the lineup.
    mutating func add(_ bowler: BowlerRecord) {
        guard !lineup.contains(where: { $0.bowlerID == bowler.id }) else { return }
        lineup.append(LineupEntry(bowlerID: bowler.id, name: bowler.name, isOwner: bowler.isOwner))
    }

    /// Add bowler's rows and Add "<name>" check, from every bowler. Names are checked
    /// against everyone, not just the listed ones, so someone already in the lineup can't
    /// be created twice.
    func addBowlerChoices(from bowlers: [BowlerRecord]) -> AddBowlerChoices {
        let candidates = bowlers.filter { bowler in !lineup.contains { $0.bowlerID == bowler.id } }
        return AddBowlerChoices(candidates: candidates, names: bowlers.map(\.name))
    }

    /// The league picker's rows: the picked center's leagues, or the leagues with no center
    /// when none is picked. Add "<name>" checks only these, so a name can repeat at
    /// another center.
    func leagues(from records: [LeagueRecord]) -> [LeagueRecord] {
        records.filter { $0.centerID == centerID }
    }

    /// Removes friends; the owner stays.
    mutating func remove(atOffsets offsets: IndexSet) {
        let removed = offsets.filter { !lineup[$0].isOwner }
        lineup.remove(atOffsets: IndexSet(removed))
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        lineup.move(fromOffsets: source, toOffset: destination)
    }

    var ownerBallID: BallID? {
        get { lineup.first(where: \.isOwner)?.ballID }
        set {
            guard let index = lineup.firstIndex(where: \.isOwner) else { return }
            lineup[index].ballID = newValue
        }
    }

    private var savedLeagueID: LeagueID? {
        eventType == .league ? leagueID : nil
    }

    var metadata: SessionMetadata {
        SessionMetadata(
            date: date, eventType: eventType, centerID: centerID, leagueID: savedLeagueID,
            oilPatternID: oilPatternID, lanes: lanes, notes: notes
        )
    }

    /// Fills in an event type's remembered values, dropping any no longer in `available`.
    /// Date, event type, lanes, notes, and who's in the lineup are kept.
    func applying(_ defaults: SessionDefaults, available: Available) -> NewSessionDraft {
        var draft = self
        draft.centerID = defaults.centerID.flatMap { available.centers.contains($0) ? $0 : nil }
        draft.leagueID = defaults.leagueID.flatMap { available.leagues.contains($0) ? $0 : nil }
        draft.oilPatternID = defaults.oilPatternID.flatMap { available.oilPatterns.contains($0) ? $0 : nil }
        draft.ownerBallID = defaults.ballID.flatMap { available.balls.contains($0) ? $0 : nil }
        draft.entryMode = defaults.entryMode ?? .pinByPin
        return draft
    }

    /// What to remember for `eventType` after a successful start.
    var defaults: SessionDefaults {
        SessionDefaults(
            centerID: centerID, leagueID: savedLeagueID, oilPatternID: oilPatternID,
            ballID: ownerBallID, entryMode: entryMode
        )
    }

    /// Creates the session and each bowler's first game, in lineup order.
    func start(in sessions: SessionRepository) throws -> SessionID {
        try sessions.startSession(
            metadata,
            bowlers: lineup.map { (bowlerID: $0.bowlerID, defaultBallID: $0.isOwner ? $0.ballID : nil) },
            entryMode: entryMode
        )
    }
}
