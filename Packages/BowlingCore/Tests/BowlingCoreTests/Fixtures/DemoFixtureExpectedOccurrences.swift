import BowlingCore
import BowlingFixtures
import Testing

// Hand-computed leave occurrences (§6 "Definitions (1b)") for a few leaves of the 1a
// report scopes, read off the scoresheets in BowlingFixtures/DemoGames.swift. The ball is
// the spare attempt's roll override when it has one, otherwise the game's default ball
// (§3.2, §6 "Ball report"). Newest first: session date descending, then game index
// descending, then frame descending, so the list reads like History.

struct ExpectedOccurrence: Sendable, Hashable {
    let game: DemoGame
    let frameIndex: Int
    let ball: DemoBall?
    let converted: Bool
}

struct ExpectedOccurrences: Sendable {
    let report: ExpectedReport
    /// Standing pins, as in the leave's name.
    let pins: [Int]
    let occurrences: [ExpectedOccurrence]
}

extension DemoFixtureExpected {
    static let occurrences: [ExpectedOccurrences] = [
        // Six, four made, as in ownerCompetition's "10" row.
        // leagueNight (2 days ago): leagueNight3 F10 "10 / X"; leagueNight1 F10 "X 10 /",
        // where roll 2 leaves the 10 and roll 3 converts it; leagueNight1 F1 "10 /^", whose
        // spare roll carries the ownerSpare override.
        // earlyLeague (16 days ago): earlyLeague2 F9 "10 -", F3 "10 /", F2 "10 -".
        ExpectedOccurrences(report: ownerCompetition, pins: [10], occurrences: [
            ExpectedOccurrence(game: .leagueNight3, frameIndex: 10, ball: .ownerStrike, converted: true),
            ExpectedOccurrence(game: .leagueNight1, frameIndex: 10, ball: .ownerStrike, converted: true),
            ExpectedOccurrence(game: .leagueNight1, frameIndex: 1, ball: .ownerSpare, converted: true),
            ExpectedOccurrence(game: .earlyLeague2, frameIndex: 9, ball: .ownerStrike, converted: false),
            ExpectedOccurrence(game: .earlyLeague2, frameIndex: 3, ball: .ownerStrike, converted: true),
            ExpectedOccurrence(game: .earlyLeague2, frameIndex: 2, ball: .ownerStrike, converted: false),
        ]),
        // One: leagueNight1 F4 "2-8 /". earlyLeague2 F10 "F / 2-8" leaves the 2-8 on a fill
        // ball, which is not a spare attempt, so it is not listed.
        ExpectedOccurrences(report: ownerCompetition, pins: [2, 8], occurrences: [
            ExpectedOccurrence(game: .leagueNight1, frameIndex: 4, ball: .ownerStrike, converted: true),
        ]),
        // Three, two made, as in ownerAllGames' "7" row: leagueNight2 F4 "7 -" (2 days ago),
        // practice1 F4 "7 /" (5 days ago), earlyLeague2 F7 "7 /" (16 days ago).
        ExpectedOccurrences(report: ownerAllGames, pins: [7], occurrences: [
            ExpectedOccurrence(game: .leagueNight2, frameIndex: 4, ball: .ownerStrike, converted: false),
            ExpectedOccurrence(game: .practice1, frameIndex: 4, ball: .ownerStrike, converted: true),
            ExpectedOccurrence(game: .earlyLeague2, frameIndex: 7, ball: .ownerStrike, converted: true),
        ]),
        // Two, none made: leagueNight3 F2 "6-7-10 7", practice1 F8 "6-7-10 7".
        ExpectedOccurrences(report: ownerAllGames, pins: [6, 7, 10], occurrences: [
            ExpectedOccurrence(game: .leagueNight3, frameIndex: 2, ball: .ownerStrike, converted: false),
            ExpectedOccurrence(game: .practice1, frameIndex: 8, ball: .ownerStrike, converted: false),
        ]),
        // One: leagueNight1 F3 "7-10 7". practiceInProgress F3 "7-10 7" is in an incomplete
        // game, which no stat counts (§6).
        ExpectedOccurrences(report: ownerAllGames, pins: [7, 10], occurrences: [
            ExpectedOccurrence(game: .leagueNight1, frameIndex: 3, ball: .ownerStrike, converted: false),
        ]),
        // Two, both made: friendCasual1 F7 "10 /", F1 "10 /". The friend's games have no
        // default ball and no override, so no ball.
        ExpectedOccurrences(report: friendAllGames, pins: [10], occurrences: [
            ExpectedOccurrence(game: .friendCasual1, frameIndex: 7, ball: nil, converted: true),
            ExpectedOccurrence(game: .friendCasual1, frameIndex: 1, ball: nil, converted: true),
        ]),
        // None: the friend never left the 2-8.
        ExpectedOccurrences(report: friendAllGames, pins: [2, 8], occurrences: []),
    ]
}

extension ExpectedOccurrences: CustomTestStringConvertible {
    var testDescription: String {
        "\(report.testDescription): \(pins.map(String.init).joined(separator: "-"))"
    }
}
