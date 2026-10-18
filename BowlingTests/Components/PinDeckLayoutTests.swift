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

    @Test func tappingAPinFindsItByHeadOrBase() {
        for pin in 1...10 {
            let frame = pins.pinFrame(of: pin)
            #expect(pins.pin(at: CGPoint(x: frame.midX, y: frame.maxY - 2)) == pin)
        }
        let head = pins.pinFrame(of: 7)
        #expect(pins.pin(at: CGPoint(x: head.midX, y: head.minY + 4)) == 7)
    }

    @Test func theFrontPinWinsWhereTwoOverlap() {
        // Pin 1's body overlaps the bottom of pin 2's, as in the drawing.
        let one = pins.hitArea(of: 1), two = pins.hitArea(of: 2)
        let overlap = one.intersection(two)
        #expect(!overlap.isNull)
        #expect(pins.pin(at: CGPoint(x: overlap.midX, y: overlap.midY)) == 1)
    }

    @Test func pinTapAreasAreAtLeast48PointsWideOnTheSmallestPhone() {
        for pin in 1...10 { #expect(pins.hitArea(of: pin).width >= 48) }
    }

    @Test func spotsOutsideAnyPinHitNothing() {
        #expect(pins.pin(at: CGPoint(x: 2, y: pins.height - 2)) == nil)
    }
}

