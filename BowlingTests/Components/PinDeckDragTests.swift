import BowlingCore
import CoreGraphics
import Testing
@testable import Bowling

@Suite struct PinDeckDragTests {
    let layout = PinDeckLayout(width: 288)

    @Test func fastSwipeMarksEveryPinOnTheWay() {
        var drag = PinDeckDrag(start: layout.center(of: 7), available: .all, standing: [], layout: layout)
        drag.move(to: layout.center(of: 10), in: layout)   // one touch event across the whole back row
        #expect(drag.standing == PinSet(pins: [7, 8, 9, 10]))
    }

    @Test func startInAGapWaitsForTheFirstPin() {
        let a = layout.center(of: 7), b = layout.center(of: 8)
        var drag = PinDeckDrag(start: CGPoint(x: (a.x + b.x) / 2, y: a.y), available: .all, standing: .all, layout: layout)
        #expect(drag.standing == .all)
        drag.move(to: b, in: layout)
        #expect(drag.standing == PinSet.all.subtracting(.pin8))
    }

    @Test func aNewTouchOrNewRackIsANewGesture() {
        let drag = PinDeckDrag(start: layout.center(of: 7), available: .all, standing: [], layout: layout)
        #expect(drag.continues(start: layout.center(of: 7), available: .all))
        #expect(!drag.continues(start: layout.center(of: 1), available: .all))   // a cancelled drag left this one behind
        #expect(!drag.continues(start: layout.center(of: 7), available: PinSet(pins: [3, 6, 10])))
    }
}
