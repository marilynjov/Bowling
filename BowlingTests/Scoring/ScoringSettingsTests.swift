import Foundation
import Testing
@testable import Bowling

@Suite struct ScoringSettingsTests {
    let suite = UserDefaults(suiteName: "test.\(UUID())")!

    @Test func defaults() {
        let settings = ScoringSettings(suite)
        #expect(settings.tapWhatFell == false)
        #expect(settings.autoAdvanceOnSpare == false)
        #expect(settings.rotateBowlers == true)
    }

    @Test func readsSavedValues() {
        suite.set(true, forKey: "scoring.tapWhatFell")
        suite.set(true, forKey: "scoring.autoAdvanceOnSpare")
        suite.set(false, forKey: "scoring.rotateBowlers")
        let settings = ScoringSettings(suite)
        #expect(settings.tapWhatFell)
        #expect(settings.autoAdvanceOnSpare)
        #expect(settings.rotateBowlers == false)
    }

    @Test func resetRestoresDefaults() {
        let settings = ScoringSettings(suite)
        settings.tapWhatFell = true
        settings.autoAdvanceOnSpare = true
        settings.rotateBowlers = false
        settings.reset()
        let fresh = ScoringSettings(suite)
        #expect(fresh.tapWhatFell == false)
        #expect(fresh.autoAdvanceOnSpare == false)
        #expect(fresh.rotateBowlers == true)
    }
}
