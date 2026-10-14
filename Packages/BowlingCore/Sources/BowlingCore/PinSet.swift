/// The pins of one rack as a bit mask: bit `n-1` is pin `n`, the same layout as
/// `Roll.pinsDownMask`, so the stored value and `rawValue` convert without remapping.
public struct PinSet: OptionSet, Sendable, Hashable, Codable {
    private static let rackMask: UInt16 = 0b11_1111_1111

    public let rawValue: UInt16

    /// Bits 10 to 15 are cleared, so a corrupt stored mask never yields an eleventh pin.
    public init(rawValue: UInt16) {
        self.rawValue = rawValue & Self.rackMask
    }

    public static let pin1 = PinSet(rawValue: 1 << 0)
    public static let pin2 = PinSet(rawValue: 1 << 1)
    public static let pin3 = PinSet(rawValue: 1 << 2)
    public static let pin4 = PinSet(rawValue: 1 << 3)
    public static let pin5 = PinSet(rawValue: 1 << 4)
    public static let pin6 = PinSet(rawValue: 1 << 5)
    public static let pin7 = PinSet(rawValue: 1 << 6)
    public static let pin8 = PinSet(rawValue: 1 << 7)
    public static let pin9 = PinSet(rawValue: 1 << 8)
    public static let pin10 = PinSet(rawValue: 1 << 9)
    public static let all = PinSet(rawValue: rackMask)

    /// Pin numbers 1...10; numbers outside that range are ignored.
    public init(pins: some Sequence<Int>) {
        self = pins.reduce(into: PinSet()) { set, pin in
            if (1...10).contains(pin) { set.insert(PinSet(rawValue: 1 << (pin - 1))) }
        }
    }

    /// Ascending pin numbers.
    public var pins: [Int] {
        (1...10).filter { contains(pin: $0) }
    }

    public var count: Int {
        rawValue.nonzeroBitCount
    }

    public func contains(pin: Int) -> Bool {
        (1...10).contains(pin) && rawValue & (1 << (pin - 1)) != 0
    }
}
