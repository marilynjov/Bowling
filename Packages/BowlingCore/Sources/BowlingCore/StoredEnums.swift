// Raw values are persisted and synced, so they may be added but never renamed or
// removed. A raw value written by a newer app version decodes to `.unknown` rather than
// failing, and the UI shows it as "Other".

public enum EntryMode: String, Sendable, Hashable, Codable, CaseIterable {
    case pinByPin, countOnly, finalOnly
    case unknown

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .unknown
    }

    public init(from decoder: any Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}

/// Stored default: casual.
public enum EventType: String, Sendable, Hashable, Codable, CaseIterable {
    case practice, league, tournament, casual
    case unknown

    /// The default stats scope.
    public static let competition: Set<EventType> = [.league, .tournament]

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .unknown
    }

    public init(from decoder: any Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}

/// Stored default: unknown, treated as casual.
public enum StatsProfile: String, Sendable, Hashable, Codable, CaseIterable {
    case casual, league, competitive, unknown

    public var effective: StatsProfile {
        self == .unknown ? .casual : self
    }

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .unknown
    }

    public init(from decoder: any Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}

/// Stored default: unknown.
public enum Handedness: String, Sendable, Hashable, Codable, CaseIterable {
    case right, left, unknown

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .unknown
    }

    public init(from decoder: any Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}

/// Stored default: strike.
public enum BallRole: String, Sendable, Hashable, Codable, CaseIterable {
    case strike, spare, both
    case unknown

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .unknown
    }

    public init(from decoder: any Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}

/// Stored default: unknown, which is also a value the user can pick.
public enum Coverstock: String, Sendable, Hashable, Codable, CaseIterable {
    case plastic, urethane, reactiveSolid, reactivePearl, reactiveHybrid, other
    case unknown

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .unknown
    }

    public init(from decoder: any Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}

/// Stored default: unknown, which is also a value the user can pick. `pancake` is the
/// plastic spare-ball core.
public enum CoreType: String, Sendable, Hashable, Codable, CaseIterable {
    case symmetric, asymmetric, pancake
    case unknown

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .unknown
    }

    public init(from decoder: any Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}

/// The user's explicit default stats scope. The stored empty string means "follow the
/// bowling style" and reads as nil on `BowlerRecord`, as does `.unknown`.
public enum StatsScope: String, Sendable, Hashable, Codable, CaseIterable {
    case competition, all, unknown

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .unknown
    }

    public init(from decoder: any Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}
