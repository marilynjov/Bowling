import BowlingCore
import BowlingData
import Foundation

/// What the game detail screen shows, loaded in one read.
struct GameDetailData: Hashable {
    struct FrameLeave: Hashable, Identifiable {
        var frameIndex: Int
        var leave: Leave
        var id: Int { frameIndex }
    }

    enum Leaves: Hashable {
        /// Every bowled frame's leave, in frame order.
        case frames([FrameLeave])
        /// A count game: "Enter pins to see leaves".
        case enterPins
        /// Final score: no leaves section.
        case hidden
    }

    struct BallUse: Hashable, Identifiable {
        var id: BallID
        var name: String
        var isDefault: Bool
        /// The frames an override was thrown in; empty for the default ball.
        var frames: [Int]
        /// "Default · Phaze" / "Hammer · frames 3 and 7" / "Hammer · frame 3".
        var text: String
    }

    var id: GameID
    var sessionID: SessionID
    /// "Game 2 · Alex".
    var title: String
    var scorecard: Scorecard
    var leaves: Leaves
    /// The default ball first, then each override once, by first frame.
    var ballsUsed: [BallUse]
    /// The game's `gameIndex` is the session's highest.
    var isLatest: Bool
    var editTarget: ScoringTarget
    var deleteRequest: DeleteRequest

    /// Ball names come from `detail(for:)`, so a retired ball keeps its name; one that is really
    /// gone reads "Deleted ball". Each ball is looked up once per load.
    /// - Throws: `RepositoryError.notFound` when the game or its session is gone.
    static func load(_ id: GameID, from store: BowlingStore) throws -> GameDetailData {
        var names: [BallID: String?] = [:]
        return try load(id, from: store, ballName: { ball in
            if let cached = names[ball] { return cached }
            let name = (try? store.balls.detail(for: ball))?.fields.name
            names[ball] = .some(name)
            return name
        })
    }

    /// - Parameter ballName: A ball's name; nil when it no longer exists, read as "Deleted ball".
    /// - Throws: `RepositoryError.notFound` when the game or its session is gone.
    static func load(_ id: GameID, from store: BowlingStore, ballName: (BallID) -> String?) throws -> GameDetailData {
        let game = try store.games.game(id)
        guard let sessionID = game.sessionID else { throw RepositoryError.notFound }
        let session = try store.sessions.session(sessionID)
        let bowlerName = session.bowlers.first { $0.bowler.id == game.bowlerID }?.bowler.name ?? ""
        let scorecard = Scorer.scorecard(for: game)
        let leaves: Leaves
        switch game.entryMode {
        case .finalOnly: leaves = .hidden
        case .countOnly: leaves = .enterPins
        default:
            // The scorer lists no leave for a strike, so it is classified here as a clean rack.
            leaves = .frames(scorecard.frames.compactMap { frame in
                let leave = frame.leave ?? (frame.marks.first == .strike ? LeaveClassifier.classify([]) : nil)
                return leave.map { FrameLeave(frameIndex: frame.frameIndex, leave: $0) }
            })
        }
        let games = session.bowlers.flatMap(\.games)
        return GameDetailData(
            id: id,
            sessionID: sessionID,
            title: String(localized: "Game \(game.gameIndex) · \(bowlerName)"),
            scorecard: scorecard,
            leaves: leaves,
            ballsUsed: ballsUsed(in: game, name: { ballName($0) ?? String(localized: "Deleted ball") }),
            isLatest: game.gameIndex == (games.map(\.gameIndex).max() ?? 0),
            editTarget: ScoringTarget(sessionID: sessionID, gameID: id, startsOnTarget: true),
            deleteRequest: .game(
                id, gameIndex: game.gameIndex, bowlerName: bowlerName, sessionID: sessionID, isOnlyGame: games.count == 1
            )
        )
    }

    private static func ballsUsed(in game: GameRecord, name: (BallID) -> String) -> [BallUse] {
        var uses: [BallUse] = []
        if let ball = game.defaultBallID {
            uses.append(BallUse(
                id: ball, name: name(ball), isDefault: true, frames: [],
                text: String(localized: "Default · \(name(ball))")
            ))
        }
        var framesByBall: [BallID: [Int]] = [:]
        var order: [BallID] = []
        for frame in game.frames {
            for ball in frame.rolls.compactMap(\.ballID) where ball != game.defaultBallID {
                if framesByBall[ball] == nil { order.append(ball) }
                if framesByBall[ball]?.last != frame.frameIndex { framesByBall[ball, default: []].append(frame.frameIndex) }
            }
        }
        for ball in order {
            let frames = framesByBall[ball] ?? []
            let list = frames.map(String.init).formatted(.list(type: .and))
            uses.append(BallUse(
                id: ball, name: name(ball), isDefault: false, frames: frames,
                text: frames.count == 1
                    ? String(localized: "\(name(ball)) · frame \(list)")
                    : String(localized: "\(name(ball)) · frames \(list)")
            ))
        }
        return uses
    }
}
