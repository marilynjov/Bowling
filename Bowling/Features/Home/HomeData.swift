import BowlingCore
import BowlingData
import Foundation

/// The unfinished session Home offers to resume, and the game Scoring opens on.
struct ResumeCard: Hashable {
    var eventType: EventType
    var centerName: String?
    /// "Game 2 · frame 6", or "Game 2" before the first roll and for final-only games.
    var progress: String
    var target: ScoringTarget
}

/// One of Home's recent sessions.
struct RecentRow: Hashable, Identifiable {
    var id: SessionID
    var date: Date
    var eventType: EventType
    var centerName: String?
    /// The owner's games in order, "187 · 201 · 176…"; "…" marks an unfinished game.
    var scores: String
}

/// Everything Home shows, read in one pass after each write.
struct HomeData: Hashable {
    var tiles: [HomeTile] = []
    var resume: ResumeCard?
    var recent: [RecentRow] = []

    /// Empty when there is no owner.
    static func load(from store: BowlingStore, now: Date = .now, calendar: Calendar = .current) -> HomeData {
        guard let owner = store.bowlers.owner() else { return HomeData() }
        return HomeData(
            tiles: tiles(for: owner, in: store, now: now, calendar: calendar),
            resume: store.sessions.resumableSession().flatMap(resumeCard),
            recent: store.sessions.sessions().prefix(3).map { recentRow($0, owner: owner.id) }
        )
    }

    /// The default scope's report, like Stats; a competition scope also gets the all-games
    /// report for the Average's second figure.
    private static func tiles(for owner: BowlerRecord, in store: BowlingStore, now: Date, calendar: Calendar) -> [HomeTile] {
        let preferCompetition = HomeTiles.prefersCompetition(scope: owner.statsScope, profile: owner.statsProfile)
        let eventTypes = store.stats.defaultEventTypes(for: owner.id, preferCompetition: preferCompetition)
        func report(_ filter: StatsFilter) -> StatsReport {
            StatsEngine.report(games: store.stats.games(matching: filter, now: now, calendar: calendar), filter: filter)
        }
        let scoped = report(StatsFilter(eventTypes: eventTypes, bowlerID: owner.id))
        let allGames = eventTypes == EventType.competition ? report(StatsFilter(bowlerID: owner.id)) : nil
        return HomeTiles.make(
            cards: StatsPreset.displayedHomeTiles(layout: owner.homeLayout, profile: owner.statsProfile),
            scoped: scoped, allGames: allGames
        )
    }

    /// The first unfinished game, bowlers in lineup order and their games by `gameIndex`.
    private static func resumeCard(_ session: SessionSummary) -> ResumeCard? {
        guard let game = session.games.first(where: { !$0.isComplete }) else { return nil }
        var progress = String(localized: "Game \(game.gameIndex)")
        if game.frames.contains(where: { !$0.rolls.isEmpty }), let next = Scorer.nextRoll(in: game) {
            progress = String(localized: "Game \(game.gameIndex) · frame \(next.frameIndex)")
        }
        return ResumeCard(
            eventType: session.eventType, centerName: session.centerName, progress: progress,
            target: ScoringTarget(sessionID: session.id, gameID: game.id)
        )
    }

    private static func recentRow(_ session: SessionSummary, owner: BowlerID) -> RecentRow {
        let scores = session.games
            .filter { $0.bowlerID == owner }
            .map { $0.isComplete ? "\($0.finalScore)" : "\($0.finalScore)…" }
            .joined(separator: " · ")
        return RecentRow(
            id: session.id, date: session.date, eventType: session.eventType,
            centerName: session.centerName, scores: scores
        )
    }
}
