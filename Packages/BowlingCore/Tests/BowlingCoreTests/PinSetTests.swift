import Foundation
import Testing
import BowlingCore

@Suite struct PinSetTests {
    @Test(arguments: 1...10)
    func pinNumberMapsToBit(pin: Int) {
        let set = PinSet(pins: [pin])
        #expect(set.rawValue == 1 << (pin - 1))
        #expect(set.pins == [pin])
        #expect(set.contains(pin: pin))
    }

    @Test func namedPinsMatchNumbers() {
        let named: [PinSet] = [.pin1, .pin2, .pin3, .pin4, .pin5, .pin6, .pin7, .pin8, .pin9, .pin10]
        for (offset, pin) in named.enumerated() {
            #expect(pin == PinSet(pins: [offset + 1]))
        }
    }

    @Test func fullRack() {
        #expect(PinSet.all.rawValue == 0x3FF)
        #expect(PinSet.all.count == 10)
        #expect(PinSet.all.pins == Array(1...10))
        #expect(PinSet(pins: 1...10) == .all)
    }

    @Test func emptySet() {
        #expect(PinSet().count == 0)
        #expect(PinSet().pins.isEmpty)
    }

    @Test func pinsAreAscendingAndCounted() {
        let set = PinSet(pins: [10, 3, 6, 3])
        #expect(set.pins == [3, 6, 10])
        #expect(set.count == 3)
        #expect(set == [.pin3, .pin6, .pin10])
    }

    @Test func outOfRangePinsAreIgnored() {
        let set = PinSet(pins: [0, 1, 11, -2])
        #expect(set == .pin1)
        #expect(!set.contains(pin: 0))
        #expect(!set.contains(pin: 11))
    }

    @Test func highBitsAreCleared() {
        #expect(PinSet(rawValue: 0xFFFF) == .all)
        #expect(PinSet(rawValue: 0xFC00).isEmpty)
    }

    @Test func standingPinsBySubtraction() {
        let down = PinSet(pins: [1, 2, 3, 5])
        #expect(PinSet.all.subtracting(down).pins == [4, 6, 7, 8, 9, 10])
    }

    @Test func codableEncodesBareRawValue() throws {
        let set = PinSet(pins: [7, 10])
        let data = try JSONEncoder().encode(set)
        #expect(String(decoding: data, as: UTF8.self) == "576")
        #expect(try JSONDecoder().decode(PinSet.self, from: data) == set)
    }

    @Test func decodingClearsHighBits() throws {
        let decoded = try JSONDecoder().decode(PinSet.self, from: Data("65535".utf8))
        #expect(decoded == .all)
    }
}
