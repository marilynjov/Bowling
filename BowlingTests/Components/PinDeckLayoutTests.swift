import CoreGraphics
import Testing
@testable import Bowling

@Suite struct PinDeckLayoutTests {
    let layout = PinDeckLayout(width: 288)   // a 320 pt phone minus 16 pt margins

    @Test func pinsAreAtLeast48PointsAtTheMinimumWidth() {
        #expect(PinDeckLayout(width: PinDeckLayout.minimumWidth).pinDiameter >= 48)
        #expect(PinDeckLayout(width: PinDeckLayout.minimumWidth - 1).pinDiameter < 48)
    }
    @Test func triangleOrder() {
        #expect(layout.center(of: 7).y == layout.center(of: 10).y)
        #expect(layout.center(of: 7).x < layout.center(of: 8).x)
        #expect(layout.center(of: 1).y > layout.center(of: 2).y)
        #expect(abs(layout.center(of: 1).x - 144) < 0.001)
        #expect(abs(layout.center(of: 5).x - 144) < 0.001)
    }
    @Test func hitTestingFindsEveryPin() {
        for pin in 1...10 { #expect(layout.pin(at: layout.center(of: pin)) == pin) }
    }
    @Test func gapsHitNothing() {
        let a = layout.center(of: 7), b = layout.center(of: 8)
        #expect(layout.pin(at: CGPoint(x: (a.x + b.x) / 2, y: a.y)) == nil)
        #expect(layout.pin(at: CGPoint(x: -10, y: -10)) == nil)
    }
}
