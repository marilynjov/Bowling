import BowlingCore
import Foundation
import SwiftData
@testable import BowlingData

/// Inserts the session, bowler, and balls `record` points to, under the record's IDs, so a
/// converted game can be compared field by field with the record it came from.
@MainActor
func insertGame(_ record: GameRecord, into context: ModelContext) throws -> Game {
    let session = try fetchOrInsertSession(record, into: context)
    let game = Game(gameIndex: record.gameIndex)
    game.id = record.id
    context.insert(game)
    game.session = session
    if let bowlerID = record.bowlerID {
        game.bowler = try fetchOrInsertBowler(bowlerID, into: context)
    }
    for ballID in Set(record.frames.flatMap(\.rolls).compactMap(\.ballID) + [record.defaultBallID].compactMap(\.self)) {
        _ = try fetchOrInsertBall(ballID, into: context)
    }
    try game.apply(record, in: context)
    try context.save()
    return game
}

@MainActor
private func fetchOrInsertSession(_ record: GameRecord, into context: ModelContext) throws -> Session {
    let id = record.sessionID ?? UUID()
    if let existing = try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })).first {
        return existing
    }
    let session = Session(date: record.sessionDate)
    session.id = id
    session.eventType = record.eventType.rawValue
    context.insert(session)
    return session
}

@MainActor
private func fetchOrInsertBowler(_ id: BowlerID, into context: ModelContext) throws -> Bowler {
    if let existing = try context.fetch(FetchDescriptor<Bowler>(predicate: #Predicate { $0.id == id })).first {
        return existing
    }
    let bowler = Bowler(name: "Bowler")
    bowler.id = id
    context.insert(bowler)
    return bowler
}

@MainActor
private func fetchOrInsertBall(_ id: BallID, into context: ModelContext) throws -> Ball {
    if let existing = try context.fetch(FetchDescriptor<Ball>(predicate: #Predicate { $0.id == id })).first {
        return existing
    }
    let ball = Ball(name: "Ball", weightPounds: 15)
    ball.id = id
    context.insert(ball)
    return ball
}

/// A fixed-seed generator, so a shuffled-order failure reproduces.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
