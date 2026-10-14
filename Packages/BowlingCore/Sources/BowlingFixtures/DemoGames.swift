import BowlingCore

/// One demo game as typed by hand. `finalScore` is typed too, never computed; its
/// frame-by-frame arithmetic is in the test target's DemoFixtureExpectedGames.swift.
struct DemoGameSpec {
    let gameIndex: Int
    let entryMode: EntryMode
    let defaultBall: DemoBall?
    let finalScore: Int
    let isComplete: Bool
    /// ScoresheetNotation, one string per frame; empty for finalOnly.
    let scoresheet: [String]
    let overrideBall: DemoBall?

    static func pinByPin(
        _ gameIndex: Int, ball: DemoBall?, score: Int, complete: Bool = true,
        override: DemoBall? = nil, _ scoresheet: [String]
    ) -> DemoGameSpec {
        DemoGameSpec(gameIndex: gameIndex, entryMode: .pinByPin, defaultBall: ball,
                     finalScore: score, isComplete: complete, scoresheet: scoresheet,
                     overrideBall: override)
    }

    static func countOnly(
        _ gameIndex: Int, ball: DemoBall?, score: Int, _ scoresheet: [String]
    ) -> DemoGameSpec {
        DemoGameSpec(gameIndex: gameIndex, entryMode: .countOnly, defaultBall: ball,
                     finalScore: score, isComplete: true, scoresheet: scoresheet,
                     overrideBall: nil)
    }

    static func finalOnly(_ gameIndex: Int, score: Int) -> DemoGameSpec {
        DemoGameSpec(gameIndex: gameIndex, entryMode: .finalOnly, defaultBall: nil,
                     finalScore: score, isComplete: true, scoresheet: [], overrideBall: nil)
    }

    func frames() -> [FrameRecord] {
        switch entryMode {
        case .pinByPin: ScoresheetNotation.pinByPinFrames(scoresheet, overrideBall: overrideBall)
        case .countOnly: ScoresheetNotation.countOnlyFrames(scoresheet, overrideBall: overrideBall)
        case .finalOnly, .unknown: []
        }
    }
}

extension DemoGame {
    var spec: DemoGameSpec {
        switch self {
        case .leagueNight1:
            .pinByPin(1, ball: .ownerStrike, score: 162, override: .ownerSpare, [
                "10 /^", "X", "7-10 7", "2-8 /", "F /",
                "X", "X", "3-6-10 10", "1-2-10 10", "X 10 /",
            ])
        case .leagueNight2:
            .pinByPin(2, ball: .ownerStrike, score: 213, [
                "X", "X", "4-5 /", "7 -", "6-10 /",
                "X", "5 F", "X", "X", "X X 10",
            ])
        case .leagueNight3:
            .pinByPin(3, ball: .ownerStrike, score: 160, [
                "3-9 /", "6-7-10 7", "9 /", "X", "1-2-4-10 /",
                "2 -", "X", "8 /", "4-7-10 10", "10 / X",
            ])
        case .leagueNightPartner1:
            .countOnly(1, ball: .partnerStrike, score: 157,
                       ["9/", "X", "72", "X", "X", "81", "9/", "63", "X", "81"])
        case .leagueNightPartner2:
            .countOnly(2, ball: .partnerStrike, score: 173,
                       ["81", "8/", "X", "9-", "7/", "X", "X", "9/", "81", "X8/"])
        case .leagueNightPartner3:
            .countOnly(3, ball: .partnerStrike, score: 179,
                       ["-9", "X", "X", "X", "9/", "8-", "7/", "X", "9-", "9/7"])
        case .tournament1:
            .pinByPin(1, ball: .ownerStrike, score: 300,
                      Array(repeating: "X", count: 9) + ["X X X"])
        case .tournament2:
            .countOnly(2, ball: .ownerStrike, score: 170,
                       ["X", "9/", "81", "X", "X", "72", "9/", "X", "8/", "9-"])
        case .tournament3:
            .finalOnly(3, score: 188)
        case .tournament4:
            .countOnly(4, ball: .ownerStrike, score: 183,
                       ["8/", "X", "9-", "7/", "X", "X", "81", "9/", "X", "XF9"])
        case .earlyLeague1:
            .countOnly(1, ball: .ownerStrike, score: 150,
                       Array(repeating: "5/", count: 9) + ["5/5"])
        case .earlyLeague2:
            .pinByPin(2, ball: .ownerStrike, score: 160, [
                "X", "10 -", "10 /", "5-7 7", "X",
                "2-4-5 /", "7 /", "X", "10 -", "F / 2-8",
            ])
        case .earlyLeague3:
            .finalOnly(3, score: 201)
        case .practice1:
            .pinByPin(1, ball: .ownerStrike, score: 181, [
                "X", "10 /", "X", "7 /", "10 -",
                "X", "X", "6-7-10 7", "3 /", "10 / 7",
            ])
        case .practice2:
            .countOnly(2, ball: .ownerStrike, score: 149,
                       ["72", "63", "X", "8/", "9-", "81", "X", "X", "7/", "81"])
        case .casualOuting1:
            .finalOnly(1, score: 142)
        case .casualOuting2:
            .countOnly(2, ball: .ownerStrike, score: 124,
                       ["9-", "81", "X", "71", "9/", "62", "X", "9/", "81", "72"])
        case .practiceInProgress:
            // Paused after the first ball of frame 5; finalScore is the last known
            // running total (contract OQ-9).
            .pinByPin(1, ball: .ownerStrike, score: 47, complete: false,
                      ["X", "10 /", "7-10 7", "X", "10"])
        case .friendCasual1:
            .pinByPin(1, ball: nil, score: 150, [
                "10 /", "7 -", "X", "6 /", "4 -",
                "X", "10 /", "7-10 -", "X", "4 -",
            ])
        case .friendCasual2:
            .finalOnly(2, score: 131)
        case .friendPractice1:
            .countOnly(1, ball: nil, score: 157,
                       ["81", "X", "9/", "72", "8/", "9-", "X", "X", "81", "9/8"])
        case .friendPractice2:
            .countOnly(2, ball: nil, score: 150,
                       ["7F", "X", "8/", "9-", "X", "9/", "81", "7/", "9-", "8/X"])
        }
    }
}
