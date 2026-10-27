import BowlingCore
import BowlingData
import Foundation

/// What the session detail screen shows, loaded in one read.
struct SessionDetailData: Hashable {
    struct GameRow: Hashable, Identifiable {
        var id: GameID
        var gameIndex: Int
        var score: Int
        var scorecard: Scorecard
        /// "Game 2".
        var title: String
        var deleteRequest: DeleteRequest
    }

    struct Section: Hashable, Identifiable {
        var id: BowlerID
        var name: String
        var series: Int
        /// "Series 590".
        var seriesText: String
        var games: [GameRow]
    }

    var id: SessionID
    var metadata: SessionMetadata
    var date: Date
    /// Event, center, league, oil pattern, and "Lanes 13–14"; what is missing is left out.
    var headerParts: [String]
    /// Nil when blank.
    var notes: String?
    /// In lineup order.
    var sections: [Section]
    /// The highest `gameIndex` among all bowlers, for "Start game N+1".
    var latestGameIndex: Int
    /// Only for the session `resumableSession()` returns.
    var resumeTarget: ScoringTarget?
    var gameCount: Int

    /// - Throws: `RepositoryError.notFound` when the session is gone.
    static func load(_ id: SessionID, from store: BowlingStore) throws -> SessionDetailData {
        let detail = try store.sessions.session(id)
        let metadata = detail.metadata
        let gameCount = detail.bowlers.map(\.games.count).reduce(0, +)
        let sections = detail.bowlers.map { bowler in
            Section(
                id: bowler.bowler.id,
                name: bowler.bowler.name,
                series: bowler.seriesTotal,
                seriesText: String(localized: "Series \(bowler.seriesTotal)"),
                games: bowler.games.map { game in
                    GameRow(
                        id: game.id,
                        gameIndex: game.gameIndex,
                        score: game.shownScore,
                        scorecard: Scorer.scorecard(for: game),
                        title: String(localized: "Game \(game.gameIndex)"),
                        deleteRequest: .game(
                            game.id, gameIndex: game.gameIndex, bowlerName: bowler.bowler.name,
                            sessionID: id, isOnlyGame: gameCount == 1
                        )
                    )
                }
            )
        }
        let lanes = metadata.lanes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resumable = store.sessions.resumableSession()
        return SessionDetailData(
            id: id,
            metadata: metadata,
            date: metadata.date,
            headerParts: [
                metadata.eventType.title,
                name(of: metadata.centerID, in: store.sessions.centers()),
                metadata.leagueID.flatMap { league in store.sessions.leagueRecords().first { $0.id == league }?.name },
                name(of: metadata.oilPatternID, in: store.sessions.oilPatterns()),
                lanes.isEmpty ? nil : String(localized: "Lanes \(lanes)"),
            ].compactMap { $0 },
            notes: notes.isEmpty ? nil : metadata.notes,
            sections: sections,
            latestGameIndex: detail.bowlers.flatMap(\.games).map(\.gameIndex).max() ?? 0,
            resumeTarget: resumable?.id == id ? resumable.flatMap(ScoringTarget.resume) : nil,
            gameCount: gameCount
        )
    }

    private static func name(of id: UUID?, in refs: [NamedRef]) -> String? {
        id.flatMap { id in refs.first { $0.id == id }?.name }
    }
}
