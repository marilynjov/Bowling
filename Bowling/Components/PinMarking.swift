import BowlingCore

/// The tap-and-drag rules for one touch on the pin deck. The first available pin touched
/// flips, and every other available pin the finger then reaches takes that same state, so
/// one swipe marks a whole leave. Create a new value for each gesture.
struct PinMarking {
    let available: PinSet
    private(set) var standing: PinSet
    private var touched: PinSet = []
    /// True when this gesture is standing pins up; nil until an available pin is touched.
    private var target: Bool?

    init(available: PinSet, standing: PinSet) {
        self.available = available
        self.standing = standing.intersection(available)
    }

    mutating func touch(_ pin: Int) {
        let set = PinSet(pins: [pin])
        guard !set.isEmpty, available.isSuperset(of: set), !touched.isSuperset(of: set) else { return }
        touched.formUnion(set)
        let up = target ?? !standing.isSuperset(of: set)
        target = up
        if up { standing.formUnion(set) } else { standing.subtract(set) }
    }
}
