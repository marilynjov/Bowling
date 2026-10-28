import BowlingCore
import Foundation
import Testing
@testable import Bowling

@Suite struct DeleteRequestTests {
    @Test func sessionTitleCountsGames() {
        let id = SessionID()
        #expect(DeleteRequest.session(id, gameCount: 3).title == "Delete this session? Its 3 games will be deleted.")
        #expect(DeleteRequest.session(id, gameCount: 1).title == "Delete this session? Its 1 game will be deleted.")
        #expect(DeleteRequest.session(id, gameCount: 3).target == .session(id))
    }

    @Test func gameTitleNamesTheBowler() {
        let game = GameID()
        let request = DeleteRequest.game(game, gameIndex: 2, bowlerName: "Alex", sessionID: SessionID(), isOnlyGame: false)
        #expect(request.title == "Delete Alex's game 2?")
        #expect(request.target == .game(game))
    }

    @Test func onlyGameDeletesTheSession() {
        let session = SessionID()
        let request = DeleteRequest.game(GameID(), gameIndex: 1, bowlerName: "Alex", sessionID: session, isOnlyGame: true)
        #expect(request.target == .session(session))
        #expect(request.title == "Delete this session? It has no other games.")
    }
}
