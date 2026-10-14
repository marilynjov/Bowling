/// What a first ball left standing (spec §5). Not stored: recomputed from the roll's
/// `PinSet`, so no `.unknown` case is needed.
public enum LeaveKind: String, Sendable, Hashable, Codable, CaseIterable {
    case strike, singlePin, makeable, split
}

public struct Leave: Sendable, Hashable, Codable {
    /// Standing after the first ball.
    public var pins: PinSet
    public var kind: LeaveKind
    public var isWashout: Bool

    public init(pins: PinSet, kind: LeaveKind, isWashout: Bool) {
        self.pins = pins
        self.kind = kind
        self.isWashout = isWashout
    }

    /// Ascending pin numbers joined by "-", for example "3-6-10"; empty for a strike.
    public var name: String {
        pins.pins.map(String.init).joined(separator: "-")
    }
}
