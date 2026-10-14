import Foundation
import SwiftData
import BowlingCore
import BowlingFixtures
@testable import BowlingData

/// Inserts the BowlingFixtures demo set as SwiftData models, for tests that need a store.
/// Test-only; the repositories (#21) own the app's conversion from value types.
enum DemoStoreSeed {
    static func insertDemoGames(relativeTo now: Date, into context: ModelContext) throws {
        let bowlers = Dictionary(uniqueKeysWithValues: DemoBowler.allCases.map { demo in
            let bowler = Bowler(name: demo.name, isOwner: demo == .owner)
            bowler.id = demo.id
            context.insert(bowler)
            return (demo.id, bowler)
        })
        let balls = Dictionary(uniqueKeysWithValues: DemoBall.allCases.map { demo in
            let ball = Ball(name: demo.name, weightPounds: 15)
            ball.id = demo.id
            context.insert(ball)
            return (demo.id, ball)
        })
        var sessions: [SessionID: Session] = [:]
        for record in DemoFixture.games(relativeTo: now) {
            let sessionID = record.sessionID!
            let session = sessions[sessionID] ?? {
                let session = Session(date: record.sessionDate)
                session.id = sessionID
                session.eventType = record.eventType.rawValue
                context.insert(session)
                sessions[sessionID] = session
                return session
            }()
            let game = Game(gameIndex: record.gameIndex)
            game.id = record.id
            game.entryMode = record.entryMode.rawValue
            game.finalScore = record.finalScore
            game.isComplete = record.isComplete
            context.insert(game)
            game.session = session
            game.bowler = record.bowlerID.flatMap { bowlers[$0] }
            game.defaultBall = record.defaultBallID.flatMap { balls[$0] }
            for frameRecord in record.frames {
                let frame = Frame(frameIndex: frameRecord.frameIndex)
                context.insert(frame)
                frame.game = game
                for rollRecord in frameRecord.rolls {
                    let roll = Roll(
                        rollIndex: rollRecord.rollIndex, pinsDownMask: Int(rollRecord.pinsDown.rawValue),
                        pinCount: rollRecord.pinCount, pinsKnown: rollRecord.pinsKnown, isFoul: rollRecord.isFoul)
                    context.insert(roll)
                    roll.frame = frame
                    roll.ball = rollRecord.ballID.flatMap { balls[$0] }
                }
            }
        }
        try context.save()
    }
}
