import BowlingCore
import Testing
@testable import Bowling

@Suite struct PinMarkingTests {
    @Test func tapTogglesOnePin() {
        var m = PinMarking(available: .all, standing: [])
        m.touch(7)
        #expect(m.standing == .pin7)
    }
    @Test func dragSetsPassedPinsToTheFirstPinsNewState() {
        var m = PinMarking(available: .all, standing: .pin8)
        for pin in [7, 8, 9] { m.touch(pin) }   // 7 goes up, so 8 stays up and 9 goes up
        #expect(m.standing == PinSet(pins: [7, 8, 9]))
    }
    @Test func dragCanKnockDown() {
        var m = PinMarking(available: .all, standing: .all)
        for pin in [4, 5, 6] { m.touch(pin) }
        #expect(m.standing == PinSet.all.subtracting(PinSet(pins: [4, 5, 6])))
    }
    @Test func unavailablePinsNeverChangeOrSetTheTarget() {   // Review Focus 2
        var m = PinMarking(available: PinSet(pins: [3, 6, 10]), standing: .pin3)
        for pin in [5, 6, 10] { m.touch(pin) }   // 5 is down from roll 1; 6 sets the target "standing"
        #expect(m.standing == PinSet(pins: [3, 6, 10]))
    }
    @Test func passingAPinTwiceDoesNotFlipItBack() {
        var m = PinMarking(available: .all, standing: [])
        for pin in [7, 8, 7] { m.touch(pin) }
        #expect(m.standing == PinSet(pins: [7, 8]))
    }
    @Test func standingOutsideAvailableIsDropped() {   // Review Focus 3
        let m = PinMarking(available: PinSet(pins: [3, 6, 10]), standing: .all)
        #expect(m.standing == PinSet(pins: [3, 6, 10]))
    }
}
