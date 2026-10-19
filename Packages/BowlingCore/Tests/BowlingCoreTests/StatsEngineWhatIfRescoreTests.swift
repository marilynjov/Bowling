import Testing
@testable import BowlingCore
import BowlingFixtures

/// The what-if leaves out a game whose rewrite does not rescore, so a Scorer change that
/// broke the rewrite would quietly shrink the card's sample. Every complete pinByPin
/// fixture game must rescore.
@Suite struct StatsEngineWhatIfRescoreTests {
    static let pinned = DemoFixture.games(relativeTo: DemoFixture.referenceDate)
        .filter { $0.entryMode == .pinByPin && $0.isComplete }

    @Test(arguments: pinned)
    func everyRewrittenFixtureGameRescores(_ game: GameRecord) {
        #expect(StatsEngine.singlePinsMade(game).score != nil)
    }
}
