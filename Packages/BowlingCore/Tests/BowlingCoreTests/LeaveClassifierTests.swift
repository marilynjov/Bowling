import Foundation
import Testing
import BowlingCore

@Suite struct LeaveClassifierTests {
    private func pins(_ name: String) -> PinSet {
        PinSet(pins: name.split(separator: "-").compactMap { Int($0) })
    }

    @Test func fixtureCoversEveryHeadPinDownLeaveOnce() {
        let names = LeaveFixture.headPinDown.map(\.name)
        #expect(names.count == 129)
        #expect(Set(names).count == 129)
        #expect(names.allSatisfy { !pins($0).contains(pin: 1) && (1...3).contains(pins($0).count) })
    }

    @Test(arguments: LeaveFixture.headPinDown)
    func headPinDownLeave(name: String, kind: LeaveKind) {
        let leave = LeaveClassifier.classify(pins(name))
        #expect(leave.kind == kind)
        #expect(leave.pins == pins(name))
        #expect(leave.name == name)
        #expect(!leave.isWashout)
    }

    @Test func emptySetIsStrike() {
        let leave = LeaveClassifier.classify([])
        #expect(leave.kind == .strike)
        #expect(leave.name == "")
        #expect(!leave.isWashout)
    }

    @Test func headPinAloneIsSinglePin() {
        #expect(LeaveClassifier.classify(.pin1).kind == .singlePin)
        #expect(LeaveClassifier.classify(.pin1).name == "1")
    }

    @Test(arguments: ["2-8", "3-9"])
    func sleeperIsMakeable(name: String) {
        #expect(LeaveClassifier.classify(pins(name)).kind == .makeable)
    }

    @Test(arguments: ["2-7", "3-10"])
    func pinBehindAndBesideSleeperIsSplit(name: String) {
        #expect(LeaveClassifier.classify(pins(name)).kind == .split)
    }

    @Test(arguments: ["1-2-10", "1-2-4-10", "1-3-7", "1-3-6-7", "1-2-8-10", "1-3-7-9"])
    func washout(name: String) {
        let leave = LeaveClassifier.classify(pins(name))
        #expect(leave.isWashout)
        #expect(leave.kind == .makeable)
        #expect(leave.name == name)
    }

    @Test(arguments: ["1-2", "1-2-4", "1-7-10", "1-2-4-7-10", "1-2-3-4-5-6-7-8-9-10"])
    func headPinStandingIsNeverSplit(name: String) {
        let leave = LeaveClassifier.classify(pins(name))
        #expect(leave.kind == .makeable)
        #expect(!leave.isWashout)
    }

    @Test(arguments: [
        ("4-6-7-10", LeaveKind.split),      // big four
        ("4-6-7-8-10", .split),             // Greek church
        ("2-4-5-8", .makeable),             // bucket
        ("3-5-6-9", .makeable),             // bucket
        ("2-4-7-8", .makeable),
        ("4-5-7-8", .split),                // 2 down in front of 4 and 5
        ("2-3-4-5-6-7-8-9-10", .split),     // 1 down in front of 2 and 3
    ])
    func largerLeave(name: String, kind: LeaveKind) {
        #expect(LeaveClassifier.classify(pins(name)).kind == kind)
    }

    @Test func leaveRoundTripsThroughCodable() throws {
        let leave = LeaveClassifier.classify(pins("4-7-10"))
        let data = try JSONEncoder().encode(leave)
        #expect(try JSONDecoder().decode(Leave.self, from: data) == leave)
    }
}
