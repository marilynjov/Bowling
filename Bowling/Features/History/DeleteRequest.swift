import BowlingCore
import Foundation

/// A pending delete, shown as a confirmation dialog titled `title`.
struct DeleteRequest: Hashable, Identifiable {
    enum Target: Hashable {
        case session(SessionID)
        case game(GameID)
    }

    var target: Target
    var title: String
    var id: Target { target }

    /// "Delete this session? Its 3 games will be deleted."
    static func session(_ id: SessionID, gameCount: Int) -> DeleteRequest {
        return DeleteRequest(
            target: .session(id),
            title: gameCount == 1
                ? String(localized: "Delete this session? Its 1 game will be deleted.")
                : String(localized: "Delete this session? Its \(gameCount) games will be deleted.")
        )
    }

    /// "Delete Alex's game 2?"; a session's only game deletes the session instead.
    static func game(
        _ id: GameID, gameIndex: Int, bowlerName: String, sessionID: SessionID, isOnlyGame: Bool
    ) -> DeleteRequest {
        guard !isOnlyGame else {
            return DeleteRequest(
                target: .session(sessionID), title: String(localized: "Delete this session? It has no other games.")
            )
        }
        return DeleteRequest(target: .game(id), title: String(localized: "Delete \(bowlerName)'s game \(gameIndex)?"))
    }
}
