import Foundation

extension StatsEngine {
    /// Below this a pattern or center joins "Other" (§6 "By condition").
    static let conditionMinimumFirstBalls = 10

    /// §6 "Ball report". `games` is already filtered; incomplete games are ignored.
    /// `maintenance` comes from `BallMaintenance` over all of the ball's games, since wear
    /// does not depend on the filter.
    public static func ballReport(for ball: BallID, games: [GameRecord], maintenance: BallMaintenance) -> BallReport {
        let used = games.filter { $0.isComplete && $0.uses(ball) }
            .sorted {
                ($0.sessionDate, $0.sessionID?.uuidString ?? "", $0.gameIndex)
                    < ($1.sessionDate, $1.sessionID?.uuidString ?? "", $1.gameIndex)
            }
        let thrown = used.map { BallDeliveries($0, ball: ball) }
        let firstBalls = thrown.flatMap(\.firstBalls)
        let attempts = thrown.flatMap(\.spareAttempts)
        let leaves = leaveRows(attempts)
        func conversion(_ kind: LeaveKind) -> Rate {
            let matching = leaves.filter { $0.leave.kind == kind }.map(\.conversion)
            return Rate(hits: matching.map(\.hits).reduce(0, +), attempts: matching.map(\.attempts).reduce(0, +))
        }
        let headPin = firstBalls.compactMap(\.headPinDown)
        let asMain = used.filter { $0.defaultBallID == ball }

        return BallReport(
            ballID: ball, gamesBowled: used.count, firstBalls: firstBalls.count,
            spareAttempts: attempts.count, firstUsed: used.first?.sessionDate,
            lastUsed: used.last?.sessionDate, maintenance: maintenance,
            strikes: strikes(firstBalls), firstBallAverage: firstBallAverage(firstBalls),
            headPin: Rate(hits: headPin.count { $0 }, attempts: headPin.count),
            averageAsMainBall: Mean(total: asMain.map(\.finalScore).reduce(0, +), count: asMain.count),
            spares: Rate(hits: attempts.count(where: \.isConverted), attempts: attempts.count),
            singlePinConversion: conversion(.singlePin), splitConversion: conversion(.split),
            leaves: leaves,
            byOilPattern: conditionRows(thrown, by: \.oilPatternID),
            byCenter: conditionRows(thrown, by: \.centerID),
            overTime: overTime(thrown)
        )
    }

    /// §6 "Comparison": one row per ball in `balls`, in that order. The caller passes the
    /// non-retired balls, which `GameRecord`s cannot tell apart.
    public static func compareBalls(_ balls: [BallID], games: [GameRecord]) -> [BallComparisonRow] {
        balls.map { ball in
            let noWear = BallMaintenance(ball: ball, games: [], events: [], resurfaceIntervalGames: nil)
            let report = ballReport(for: ball, games: games, maintenance: noWear)
            return BallComparisonRow(
                ballID: ball, gamesBowled: report.gamesBowled, averageAsMainBall: report.averageAsMainBall,
                strikes: report.strikes, firstBallAverage: report.firstBallAverage, spares: report.spares
            )
        }
    }

    private static func strikes(_ firstBalls: [BallDeliveries.FirstBall]) -> Rate {
        Rate(hits: firstBalls.count(where: \.isStrike), attempts: firstBalls.count)
    }

    private static func firstBallAverage(_ firstBalls: [BallDeliveries.FirstBall]) -> Mean {
        Mean(total: firstBalls.map(\.pinCount).reduce(0, +), count: firstBalls.count)
    }

    /// Groups with at least `conditionMinimumFirstBalls` first balls, most first, ties by
    /// UUID string so the order is stable; then "Other" when it has any first balls.
    private static func conditionRows(_ thrown: [BallDeliveries], by key: KeyPath<GameRecord, UUID?>) -> [ConditionRow] {
        let groups = Dictionary(grouping: thrown) { $0.game[keyPath: key] }.mapValues { $0.flatMap(\.firstBalls) }
        func isShown(_ id: UUID?, _ firstBalls: [BallDeliveries.FirstBall]) -> Bool {
            id != nil && firstBalls.count >= conditionMinimumFirstBalls
        }
        let rows = groups.filter { isShown($0.key, $0.value) }
            .sorted { ($1.value.count, $0.key!.uuidString) < ($0.value.count, $1.key!.uuidString) }
            .map { ConditionRow(id: $0.key, strikes: strikes($0.value), firstBallAverage: firstBallAverage($0.value)) }
        let folded = groups.filter { !isShown($0.key, $0.value) }.values.flatMap { $0 }
        let other = folded.isEmpty ? [] : [ConditionRow(id: nil, strikes: strikes(folded), firstBallAverage: firstBallAverage(folded))]
        return rows + other
    }

    /// One point per session with at least one first ball thrown with the ball. A game
    /// without a session is its own group.
    private static func overTime(_ thrown: [BallDeliveries]) -> [BallTrendPoint] {
        let sessions = thrown.reduce(into: [[BallDeliveries]]()) { groups, game in
            if let id = game.game.sessionID, groups.last?.last?.game.sessionID == id {
                groups[groups.count - 1].append(game)
            } else {
                groups.append([game])
            }
        }
        return sessions.compactMap { session in
            let firstBalls = session.flatMap(\.firstBalls)
            guard !firstBalls.isEmpty else { return nil }
            return BallTrendPoint(sessionID: session[0].game.sessionID, date: session[0].game.sessionDate,
                                  strikes: strikes(firstBalls))
        }
    }
}

/// The rolls of one game thrown with one ball. A first ball belongs to the ball that threw
/// it; a spare attempt to the ball that threw the second roll, at the leave.
struct BallDeliveries {
    struct FirstBall {
        var pinCount: Int
        var isStrike: Bool
        /// Nil when the pins are unknown (countOnly) or the roll was a foul.
        var headPinDown: Bool?
    }

    let game: GameRecord
    var firstBalls: [FirstBall] = []
    var spareAttempts: [SpareAttempt] = []

    /// Follows `RollTally`'s rules for first balls and spare attempts (§6), with
    /// applicability: finalOnly and unknown entry modes have no rolls to count, and only
    /// pinByPin has pins for head pin rate and leaves.
    init(_ game: GameRecord, ball: BallID) {
        self.game = game
        guard [.countOnly, .pinByPin].contains(game.entryMode) else { return }
        let pinsKnown = game.entryMode == .pinByPin
        func thrownWith(_ roll: RollRecord) -> Bool { (roll.ballID ?? game.defaultBallID) == ball }

        for frame in Scorer.playedFrames(game) {
            let marks = frame.marks
            for (index, (roll, rack)) in zip(frame.rolls, frame.racks).enumerated() where rack.isFresh {
                if thrownWith(roll) {
                    firstBalls.append(FirstBall(
                        pinCount: roll.pinCount, isStrike: marks[index] == .strike,
                        headPinDown: pinsKnown && !roll.isFoul ? roll.pinsDown.contains(.pin1) : nil
                    ))
                }
                // A frame 10 fill ball that leaves pins has no next roll: not a spare attempt.
                guard marks[index] != .strike, index + 1 < frame.rolls.count,
                      thrownWith(frame.rolls[index + 1]) else { continue }
                let standing = roll.isFoul || !pinsKnown ? nil : frame.racks[index + 1].pins
                spareAttempts.append(SpareAttempt(isConverted: marks[index + 1] == .spare,
                                                  leave: standing.map(LeaveClassifier.classify)))
            }
        }
    }
}
