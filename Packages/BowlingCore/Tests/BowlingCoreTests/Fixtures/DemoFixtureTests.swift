import Foundation
import Testing
import BowlingCore
import BowlingFixtures

@Suite struct DemoFixtureTests {
    private let games = DemoFixture.games(relativeTo: DemoFixture.referenceDate)

    private func record(_ demo: DemoGame) throws -> GameRecord {
        try #require(games.first { $0.id == demo.id })
    }

    // MARK: Shape

    @Test func referenceDateIsMiddayOnTheContractDate() {
        #expect(DemoFixture.referenceDate.ISO8601Format() == "2026-10-14T12:00:00Z")
    }

    @Test func everyDemoGameAppearsOnceInOrder() {
        #expect(games.map(\.id) == DemoGame.allCases.map(\.id))
        #expect(Set(games.map(\.id)).count == games.count)
        #expect((18...24).contains(games.count))
    }

    @Test func gamesRoundTripThroughJSON() throws {
        let data = try JSONEncoder().encode(games)
        #expect(try JSONDecoder().decode([GameRecord].self, from: data) == games)
    }

    @Test func gamesAreTheSameForTheSameDate() {
        #expect(DemoFixture.games(relativeTo: DemoFixture.referenceDate) == games)
    }

    @Test func sessionDatesAreDayOffsetsFromNow() throws {
        let calendar = Calendar(identifier: .gregorian)
        for game in games {
            let session = try #require(DemoSession.allCases.first { $0.id == game.sessionID })
            let days = calendar.dateComponents(
                [.day], from: game.sessionDate, to: DemoFixture.referenceDate
            ).day
            #expect(days == session.daysAgo, "\(session)")
            #expect(game.eventType == session.eventType)
        }
    }

    @Test func gameIndexCountsFromOnePerBowlerAndSession() {
        let groups = Dictionary(grouping: games) { "\($0.sessionID!)-\($0.bowlerID!)" }
        for group in groups.values {
            #expect(group.map(\.gameIndex) == Array(1...group.count))
        }
    }

    // MARK: Coverage the contract asks for (section 5)

    @Test func coversEveryEntryModeAndEventType() {
        #expect(Set(games.map(\.entryMode)) == [.pinByPin, .countOnly, .finalOnly])
        #expect(Set(games.map(\.eventType)) == [.practice, .league, .tournament, .casual])
    }

    @Test func coversEveryFoulPosition() {
        let fouls = games.flatMap(RollWalk.rolls(of:)).filter(\.roll.isFoul)
        #expect(fouls.contains { $0.frameIndex < 10 && $0.roll.rollIndex == 1 })
        #expect(fouls.contains { $0.frameIndex < 10 && $0.roll.rollIndex == 2 })
        #expect(fouls.contains { $0.frameIndex == 10 && $0.roll.rollIndex == 1 })
        #expect(fouls.contains { $0.frameIndex == 10 && $0.roll.rollIndex == 2 })
    }

    @Test func firstBallFoulIsFollowedByAFullRackSpare() throws {
        let frame = try #require(record(.leagueNight1).frames.first { $0.frameIndex == 5 })
        #expect(frame.rolls.map(\.isFoul) == [true, false])
        #expect(frame.rolls[1].pinsDown == .all)
    }

    @Test func friendHasOnlyCasualAndPracticeGames() {
        let friendGames = games.filter { $0.bowlerID == DemoBowler.friend.id }
        #expect(!friendGames.isEmpty)
        #expect(friendGames.allSatisfy { [.casual, .practice].contains($0.eventType) })
    }

    @Test func leagueNightIsAThreeGameSessionForTwoBowlers() {
        let night = games.filter { $0.sessionID == DemoSession.leagueNight.id }
        #expect(Set(night.map(\.bowlerID)) == [DemoBowler.owner.id, DemoBowler.partner.id])
        #expect(night.count == 6)
        #expect(night.allSatisfy { $0.eventType == .league })
    }

    @Test func onlyThePracticeInProgressIsIncomplete() throws {
        #expect(games.filter { !$0.isComplete }.map(\.id) == [DemoGame.practiceInProgress.id])
        #expect(try record(.practiceInProgress).frames.count == 5)
    }

    @Test func aRollOverridesTheDefaultBall() throws {
        let game = try record(.leagueNight1)
        #expect(game.defaultBallID == DemoBall.ownerStrike.id)
        let overrides = game.frames.flatMap(\.rolls).compactMap(\.ballID)
        #expect(overrides == [DemoBall.ownerSpare.id])
    }

    @Test func ballsBelongToTheirBowlers() {
        for game in games {
            guard let ballID = game.defaultBallID else { continue }
            let ball = DemoBall.allCases.first { $0.id == ballID }
            #expect(ball?.owner.id == game.bowlerID)
        }
    }

    // MARK: Structure (spec §4, checked directly)

    @Test(arguments: DemoGame.allCases)
    func gameIsStructurallyValid(_ demo: DemoGame) throws {
        let game = try record(demo)
        if game.entryMode == .finalOnly {
            #expect(game.frames.isEmpty)
            #expect((0...300).contains(game.finalScore))
            #expect(game.isComplete)
            return
        }
        #expect(game.frames.map(\.frameIndex) == Array(1...game.frames.count))
        for frame in game.frames {
            #expect(frame.rolls.map(\.rollIndex) == Array(1...frame.rolls.count))
            let counts = frame.rolls.map(\.pinCount)
            if frame.frameIndex < 10 {
                #expect(frame.rolls.count <= 2, "frame \(frame.frameIndex)")
                #expect(counts.first != 10 || counts.count == 1, "roll after strike")
            } else if counts.count == 3 {
                #expect(counts[0] == 10 || counts[0] + counts[1] == 10, "unearned third roll")
            }
        }
        for walked in RollWalk.rolls(of: game) {
            let roll = walked.roll
            let at = "frame \(walked.frameIndex) roll \(roll.rollIndex)"
            #expect((0...walked.standingCountBefore).contains(roll.pinCount), "\(at)")
            if roll.isFoul {
                #expect(roll.pinCount == 0 && roll.pinsDown.isEmpty, "\(at)")
            }
            if game.entryMode == .pinByPin {
                #expect(roll.pinsKnown, "\(at)")
                #expect(roll.pinsDown.isSubset(of: walked.standingBefore), "\(at)")
                #expect(roll.pinCount == roll.pinsDown.count, "\(at)")
            } else {
                #expect(!roll.pinsKnown && roll.pinsDown.isEmpty, "\(at)")
            }
        }
    }

    @Test(arguments: DemoGame.allCases)
    func completenessMatchesTheFrames(_ demo: DemoGame) throws {
        let game = try record(demo)
        guard game.entryMode != .finalOnly else { return }
        let tenth = game.frames.first { $0.frameIndex == 10 }?.rolls.map(\.pinCount)
        let tenthIsDone = tenth.map { rolls in
            rolls.count == (rolls.first == 10 || rolls.prefix(2).reduce(0, +) == 10 ? 3 : 2)
        } ?? false
        #expect(game.isComplete == tenthIsDone)
    }
}
