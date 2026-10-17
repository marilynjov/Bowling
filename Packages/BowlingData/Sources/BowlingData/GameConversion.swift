import BowlingCore
import Foundation
import SwiftData

// Conversions read stored enum strings straight into the BowlingCore enums, not through the
// model enums, because the model enums fall back to a default case (pinByPin, casual) while
// BowlingCore keeps `.unknown`, which the app shows as "Other".

extension Game {
    /// Frames sorted by `frameIndex` and rolls by `rollIndex`; relationship order is never used.
    func record() -> GameRecord {
        GameRecord(
            id: id,
            bowlerID: bowler?.id,
            gameIndex: gameIndex,
            entryMode: BowlingCore.EntryMode(storedValue: entryMode),
            defaultBallID: defaultBall?.id,
            finalScore: finalScore,
            isComplete: isComplete,
            frames: (frames ?? []).sorted { $0.frameIndex < $1.frameIndex }.map { $0.record() },
            sessionID: session?.id,
            sessionDate: session?.date ?? createdAt,
            eventType: session.map { BowlingCore.EventType(storedValue: $0.eventType) } ?? .unknown,
            centerID: session?.center?.id, leagueID: session?.league?.id, oilPatternID: session?.oilPattern?.id
        )
    }

    /// Writes the game-owned fields of `record` onto this game. Session context, `id`, and
    /// `bowlerID` are not game-owned and are ignored. Frames and rolls are matched by index
    /// and updated in place, so a roll added to a game does not re-create, and re-sync, the
    /// rows before it. An `.unknown` entry mode leaves the stored raw string untouched.
    ///
    /// Does not validate or save; repositories do both.
    /// - Throws: `RepositoryError.notFound` when a ball ID has no ball.
    func apply(_ record: GameRecord, in context: ModelContext) throws {
        let balls = try BallLookup(context: context)
        let newDefaultBall = try balls.ball(record.defaultBallID)

        gameIndex = record.gameIndex
        if record.entryMode != .unknown { entryMode = record.entryMode.rawValue }
        defaultBall = newDefaultBall
        finalScore = record.finalScore
        isComplete = record.isComplete

        var existing = Dictionary(grouping: frames ?? [], by: \.frameIndex)
        for frameRecord in record.frames {
            let frame = existing.removeValue(forKey: frameRecord.frameIndex)?.first ?? {
                let frame = Frame(frameIndex: frameRecord.frameIndex)
                context.insert(frame)
                frame.game = self
                return frame
            }()
            try frame.apply(frameRecord, balls: balls, in: context)
        }
        existing.values.joined().forEach(context.delete)
        updatedAt = .now
    }
}

extension Frame {
    func record() -> FrameRecord {
        FrameRecord(
            frameIndex: frameIndex,
            rolls: (rolls ?? []).sorted { $0.rollIndex < $1.rollIndex }.map { $0.record() }
        )
    }

    fileprivate func apply(_ record: FrameRecord, balls: BallLookup, in context: ModelContext) throws {
        var existing = Dictionary(grouping: rolls ?? [], by: \.rollIndex)
        for rollRecord in record.rolls {
            let roll = existing.removeValue(forKey: rollRecord.rollIndex)?.first ?? {
                let roll = Roll(rollIndex: rollRecord.rollIndex)
                context.insert(roll)
                roll.frame = self
                return roll
            }()
            try roll.apply(rollRecord, balls: balls)
        }
        existing.values.joined().forEach(context.delete)
    }
}

extension Roll {
    func record() -> RollRecord {
        RollRecord(
            rollIndex: rollIndex,
            pinsDown: PinSet(rawValue: UInt16(truncatingIfNeeded: pinsDownMask)),
            pinCount: pinCount,
            pinsKnown: pinsKnown,
            isFoul: isFoul,
            ballID: ball?.id
        )
    }

    fileprivate func apply(_ record: RollRecord, balls: BallLookup) throws {
        let newBall = try balls.ball(record.ballID)
        guard self.record() != record else { return }
        pinsDownMask = Int(record.pinsDown.rawValue)
        pinCount = record.pinCount
        pinsKnown = record.pinsKnown
        isFoul = record.isFoul
        ball = newBall
        updatedAt = .now
    }
}

/// Every ball, fetched once per write instead of once per roll.
private struct BallLookup {
    let byID: [BallID: Ball]

    init(context: ModelContext) throws {
        byID = Dictionary(try context.fetch(FetchDescriptor<Ball>()).map { ($0.id, $0) }) { first, _ in first }
    }

    func ball(_ id: BallID?) throws -> Ball? {
        guard let id else { return nil }
        guard let ball = byID[id] else { throw RepositoryError.notFound }
        return ball
    }
}
