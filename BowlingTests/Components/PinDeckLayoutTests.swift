import CoreGraphics
import Testing
@testable import Bowling

@Suite struct PinDeckLayoutTests {
    let layout = PinDeckLayout(width: 288)   // a 320 pt phone minus 16 pt margins

    @Test func pinsAreAtLeast48PointsOnTheSmallestPhone() { #expect(layout.pinDiameter >= 48) }
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

    // MARK: Pins style (the drawn pins and spots)

    let pins = PinDeckLayout(width: 288, style: .pins)

    @Test func pinsStandOnATriangleOfSpots() {
        #expect(pins.center(of: 7).y == pins.center(of: 10).y)
        #expect(pins.center(of: 7).y < pins.center(of: 4).y)
        #expect(pins.center(of: 2).y < pins.center(of: 1).y)
        #expect(abs(pins.center(of: 1).x - 144) < 0.001)
        // Spots line up with the circles style, so both styles mark the same pin under a finger.
        for pin in 1...10 { #expect(pins.center(of: pin).x == layout.center(of: pin).x) }
    }

    @Test func everyPinFitsInsideTheDeck() {
        for pin in 1...10 {
            let frame = pins.pinFrame(of: pin)
            #expect(frame.minY >= 0 && frame.maxY <= pins.height)
            #expect(frame.minX >= 0 && frame.maxX <= pins.width)
        }
    }

    @Test func pinsAreTallerThanTheyAreWide() {
        let frame = pins.pinFrame(of: 1)
        #expect(frame.height > frame.width * 2)
    }

    @Test func tappingAPinFindsItByItsBelly() {
        for pin in 1...10 {
            let frame = pins.pinFrame(of: pin)
            let belly = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.64)
            #expect(pins.pin(at: belly) == pin)
            // As wide as a circle in the circles style, well past the pin's own edge.
            #expect(pins.pin(at: CGPoint(x: belly.x + pins.pinDiameter / 2 - 1, y: belly.y)) == pin)
        }
    }

    @Test func theTopOfAPinIsNotATapTarget() {
        for pin in 1...10 {
            let frame = pins.pinFrame(of: pin)
            #expect(pins.pin(at: CGPoint(x: frame.midX, y: frame.minY + 4)) != pin)
        }
    }

    @Test func pinTapAreasAreTheCirclesStyleSize() {
        for pin in 1...10 {
            #expect(pins.hitArea(of: pin).width == layout.pinDiameter)
            #expect(pins.hitArea(of: pin).height == layout.pinDiameter)
        }
    }

    @Test func pinTapCirclesNeverOverlap() {
        for a in 1...9 {
            for b in (a + 1)...10 {
                let p = pins.hitArea(of: a), q = pins.hitArea(of: b)
                #expect(hypot(p.midX - q.midX, p.midY - q.midY) >= pins.pinDiameter)
            }
        }
    }

    @Test func spotsOutsideAnyPinHitNothing() {
        #expect(pins.pin(at: CGPoint(x: 2, y: pins.height - 2)) == nil)
    }
}

