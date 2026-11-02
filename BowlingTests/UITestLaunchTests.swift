import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct UITestLaunchTests {
    @Test func activeOnlyWithTheArgument() {
        #expect(UITestLaunch.isActive(["Bowling", "-uiTesting"]))
        #expect(!UITestLaunch.isActive(["Bowling"]))
    }

    @Test func storeHasOwnerSam() throws {
        let store = try UITestLaunch.openStore()
        let owner = try #require(store.bowlers.owner())
        #expect(owner.name == "Sam")
        #expect(owner.statsProfile == .league)
    }

    @Test func defaultsStartEmpty() {
        UITestLaunch.defaults().set(true, forKey: "leftover")
        #expect(UITestLaunch.defaults().object(forKey: "leftover") == nil)
    }
}
