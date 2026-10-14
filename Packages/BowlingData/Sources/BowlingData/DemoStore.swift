import BowlingCore
import BowlingFixtures
import Foundation

extension BowlingStore {
    /// In-memory store seeded with every DemoFixture value. Used by every preview.
    ///
    /// Seeding goes through the repository write paths, so the demo data gets the same
    /// validation, scoring, and lineup order as data the user enters. The repositories mint
    /// random IDs; each one is swapped for its fixture ID right away, so previews and tests
    /// can name a bowler, ball, session, or game directly.
    /// - Parameter now: Session dates are whole days before it (`DemoSession.daysAgo`).
    public static func demo(now: Date = .now) throws -> BowlingStore {
        let store = try BowlingStore(inMemory: true)
        try store.seedBowlers()
        try store.seedBalls()
        let games = Dictionary(grouping: DemoFixture.games(relativeTo: now)) { $0.sessionID }
        for session in DemoSession.allCases {
            try store.seed(session, games: games[session.id] ?? [])
        }
        return store
    }

    private func seedBowlers() throws {
        for bowler in DemoBowler.allCases {
            let record = bowler == .owner
                ? try bowlers.createOwner(name: bowler.name, handedness: .right, statsProfile: .league)
                : try bowlers.createBowler(name: bowler.name)
            try context.write { try context.bowler(record.id).id = bowler.id }
        }
    }

    private func seedBalls() throws {
        for ball in DemoBall.allCases {
            let summary = try balls.addBall(name: ball.name, weightPounds: 15, intendedRole: ball.role, brand: "")
            try context.write { try context.ball(summary.id).id = ball.id }
        }
    }

    /// Starts the session with game 1 of each bowler, then adds one game per bowler with
    /// `startNextGame` until the fixture's games run out. The lineup is the fixture's order.
    /// - Parameter games: The session's fixture games, in `DemoGame` order.
    private func seed(_ fixture: DemoSession, games fixtureGames: [GameRecord]) throws {
        let rounds = Dictionary(grouping: fixtureGames, by: \.gameIndex).sorted { $0.key < $1.key }.map(\.value)
        guard let first = rounds.first else { return }
        let metadata = SessionMetadata(date: first[0].sessionDate, eventType: fixture.eventType)
        let created = try sessions.startSession(
            metadata, bowlers: first.map { ($0.bowlerID!, $0.defaultBallID) }, entryMode: first[0].entryMode
        )
        try context.write { try context.session(created).id = fixture.id }

        for (offset, round) in rounds.enumerated() {
            let newGames = offset == 0
                ? try sessions.session(fixture.id).bowlers.compactMap { $0.games.first?.id }
                : try games.startNextGame(in: fixture.id)
            for gameID in newGames {
                let bowlerID = try games.game(gameID).bowlerID
                guard let record = round.first(where: { $0.bowlerID == bowlerID }) else { continue }
                try context.write { try context.game(gameID).id = record.id }
                _ = try games.save(record)
            }
        }
    }
}
