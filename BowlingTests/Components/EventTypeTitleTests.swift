import BowlingCore
import Testing
@testable import Bowling

@Suite struct EventTypeTitleTests {
    @Test func eventTitles() {
        let types: [EventType] = [.practice, .league, .tournament, .casual, .unknown]
        #expect(types.map(\.title) == ["Practice", "League", "Tournament", "Casual", "Other"])
    }
}
