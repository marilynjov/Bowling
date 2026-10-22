import Foundation
import Testing
@testable import Bowling

@Suite struct ScoringSettingsTests {
    let suite = UserDefaults(suiteName: "test.\(UUID())")!

    @Test func defaultsAreOff() {
        let settings = ScoringSettings(suite)
        #expect(settings.tapWhatFell == false)
        #expect(settings.autoAdvanceOnSpare == false)
    }

    @Test func readsSavedValues() {
        suite.set(true, forKey: "scoring.tapWhatFell")
        suite.set(true, forKey: "scoring.autoAdvanceOnSpare")
        let settings = ScoringSettings(suite)
        #expect(settings.tapWhatFell)
        #expect(settings.autoAdvanceOnSpare)
    }
}
