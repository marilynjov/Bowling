import BowlingCore
import Foundation
import SwiftData

@MainActor
public final class SessionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Newest first; sessions on the same date by newest created.
    public func sessions() -> [SessionSummary] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map { $0.summary() }
    }

    public func session(_ id: SessionID) throws -> SessionDetail {
        try context.session(id).detail()
    }

    /// The newest session with an incomplete game, for Home's "Resume session".
    public func resumableSession() -> SessionSummary? {
        sessions().first { !$0.isComplete }
    }

    /// Creates the session and game 1 for each bowler.
    /// - Throws: `.notFound` when a bowler, ball, center, league, or pattern does not exist.
    public func startSession(
        _ metadata: SessionMetadata,
        bowlers: [(bowlerID: BowlerID, defaultBallID: BallID?)],
        entryMode: EntryMode
    ) throws -> SessionID {
        let references = try MetadataReferences(metadata, in: context)
        let players = try bowlers.map { entry in
            (bowler: try context.bowler(entry.bowlerID), ball: try entry.defaultBallID.map(context.ball))
        }
        return try context.write {
            let session = Session(date: metadata.date)
            context.insert(session)
            session.apply(metadata, references)
            for player in players {
                let game = Game(gameIndex: 1)
                context.insert(game)
                if entryMode != .unknown { game.entryMode = entryMode.rawValue }
                game.session = session
                game.bowler = player.bowler
                game.defaultBall = player.ball
            }
            return session.id
        }
    }

    /// A casual session dated `now` with one complete finalOnly game for the owner.
    /// - Throws: `.notFound` before first launch, `.invalidGame` outside 0 through 300.
    public func quickScore(finalScore: Int, now: Date) throws -> SessionID {
        guard let owner = context.owner() else { throw RepositoryError.notFound }
        let errors = Scorer.validate(GameRecord(
            gameIndex: 1, entryMode: .finalOnly, finalScore: finalScore, isComplete: true,
            sessionDate: now, eventType: .casual
        ))
        guard errors.isEmpty else { throw RepositoryError.invalidGame(errors) }
        return try context.write {
            let session = Session(date: now, eventType: .casual)
            context.insert(session)
            let game = Game(gameIndex: 1, entryMode: .finalOnly)
            context.insert(game)
            game.session = session
            game.bowler = owner
            game.finalScore = finalScore
            game.isComplete = true
            return session.id
        }
    }

    public func updateMetadata(_ id: SessionID, _ metadata: SessionMetadata) throws {
        let session = try context.session(id)
        let references = try MetadataReferences(metadata, in: context)
        try context.write { session.apply(metadata, references) }
    }

    /// Cascades to the session's games, frames, and rolls.
    public func deleteSession(_ id: SessionID) throws {
        let session = try context.session(id)
        try context.write { context.delete(session) }
    }

    // MARK: Pickers, by name

    public func centers() -> [NamedRef] {
        Self.byName((try? context.fetch(FetchDescriptor<BowlingCenter>())) ?? [], \.id, \.name)
    }

    public func leagues() -> [NamedRef] {
        Self.byName((try? context.fetch(FetchDescriptor<League>())) ?? [], \.id, \.name)
    }

    public func oilPatterns() -> [NamedRef] {
        Self.byName((try? context.fetch(FetchDescriptor<OilPattern>())) ?? [], \.id, \.name)
    }

    public func createCenter(name: String) throws -> CenterID {
        try context.write {
            let center = BowlingCenter(name: name)
            context.insert(center)
            return center.id
        }
    }

    public func createLeague(name: String, centerID: CenterID?) throws -> LeagueID {
        let center = try centerID.map(context.center)
        return try context.write {
            let league = League(name: name)
            context.insert(league)
            league.center = center
            return league.id
        }
    }

    public func createOilPattern(name: String) throws -> OilPatternID {
        try context.write {
            let pattern = OilPattern(name: name)
            context.insert(pattern)
            return pattern.id
        }
    }

    private static func byName<T>(_ models: [T], _ id: KeyPath<T, UUID>, _ name: KeyPath<T, String>) -> [NamedRef] {
        models
            .map { NamedRef(id: $0[keyPath: id], name: $0[keyPath: name]) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// The models a `SessionMetadata` points to, fetched before any write so a missing one
/// refuses the write instead of leaving it half done.
private struct MetadataReferences {
    let center: BowlingCenter?
    let league: League?
    let oilPattern: OilPattern?

    @MainActor
    init(_ metadata: SessionMetadata, in context: ModelContext) throws {
        center = try metadata.centerID.map(context.center)
        league = try metadata.leagueID.map(context.league)
        oilPattern = try metadata.oilPatternID.map(context.oilPattern)
    }
}

extension Session {
    fileprivate func apply(_ metadata: SessionMetadata, _ references: MetadataReferences) {
        date = metadata.date
        if metadata.eventType != .unknown { eventType = metadata.eventType.rawValue }
        center = references.center
        league = references.league
        oilPattern = references.oilPattern
        lanes = metadata.lanes
        notes = metadata.notes
        updatedAt = .now
    }

    var metadata: SessionMetadata {
        SessionMetadata(
            date: date, eventType: BowlingCore.EventType(storedValue: eventType), centerID: center?.id,
            leagueID: league?.id, oilPatternID: oilPattern?.id, lanes: lanes, notes: notes
        )
    }

    /// Each bowler's games by `gameIndex`, bowlers the owner first and then by name.
    /// Games whose bowler is gone are left out.
    func gamesByBowler() -> [(bowler: Bowler, games: [Game])] {
        let grouped = Dictionary(grouping: (games ?? []).filter { $0.bowler != nil }) { $0.bowler!.persistentModelID }
        return grouped.values
            .map { games in (bowler: games[0].bowler!, games: games.sorted { $0.gameIndex < $1.gameIndex }) }
            .sorted { Bowler.ownerThenName($0.bowler, $1.bowler) }
    }

    func summary() -> SessionSummary {
        let groups = gamesByBowler()
        let unowned = (games ?? []).filter { $0.bowler == nil }.sorted { $0.gameIndex < $1.gameIndex }
        let records = (groups.flatMap(\.games) + unowned).map { $0.record() }
        return SessionSummary(
            id: id, date: date, eventType: BowlingCore.EventType(storedValue: eventType),
            centerName: center?.name, leagueName: league?.name, bowlerCount: groups.count,
            games: records, isComplete: records.allSatisfy(\.isComplete)
        )
    }

    func detail() -> SessionDetail {
        let bowlers = gamesByBowler().map { group in
            let games = group.games.map { $0.record() }
            return SessionBowler(
                bowler: group.bowler.record(), games: games, seriesTotal: games.map(\.finalScore).reduce(0, +)
            )
        }
        return SessionDetail(id: id, metadata: metadata, bowlers: bowlers)
    }
}
