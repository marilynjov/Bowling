/// Spec §5. If bowlers disagree with a classification, edit `adjacentPairs` or
/// `inFront`; the test fixture pins every two- and three-pin leave with the head pin down.
public enum LeaveClassifier {
    /// Pins that touch, plus the sleepers 2-8 and 3-9: those do not touch, but no pin
    /// stands between them, so USBC does not count them as splits.
    static let adjacentPairs: [(Int, Int)] = [
        (1, 2), (1, 3), (2, 3), (2, 4), (2, 5), (3, 5), (3, 6), (4, 5), (5, 6),
        (4, 7), (4, 8), (5, 8), (5, 9), (6, 9), (6, 10), (7, 8), (8, 9), (9, 10),
        (2, 8), (3, 9),
    ]

    /// Each pin and the two pins directly behind it. A down pin in front of two standing
    /// pins makes a split even when they touch, for example the 4-5 with the 2 down.
    static let inFront: [(front: Int, behind: PinSet)] = [
        (1, [.pin2, .pin3]), (2, [.pin4, .pin5]), (3, [.pin5, .pin6]),
        (4, [.pin7, .pin8]), (5, [.pin8, .pin9]), (6, [.pin9, .pin10]),
    ]

    static let washouts: Set<PinSet> = Set(
        [[1, 2, 10], [1, 2, 4, 10], [1, 3, 7], [1, 3, 6, 7], [1, 2, 8, 10], [1, 3, 7, 9]]
            .map { PinSet(pins: $0) }
    )

    /// Input is the set left standing after a first ball.
    public static func classify(_ standing: PinSet) -> Leave {
        Leave(pins: standing, kind: kind(of: standing), isWashout: washouts.contains(standing))
    }

    private static func kind(of standing: PinSet) -> LeaveKind {
        switch standing.count {
        case 0: .strike
        case 1: .singlePin
        case _ where standing.contains(.pin1): .makeable
        case _ where !isConnected(standing) || isBlocked(standing): .split
        default: .makeable
        }
    }

    private static func isConnected(_ standing: PinSet) -> Bool {
        let pins = standing.pins
        var reached: Set<Int> = [pins[0]]
        var frontier = [pins[0]]
        while let pin = frontier.popLast() {
            for (a, b) in adjacentPairs {
                let other = a == pin ? b : b == pin ? a : nil
                if let other, standing.contains(pin: other), reached.insert(other).inserted {
                    frontier.append(other)
                }
            }
        }
        return reached.count == pins.count
    }

    private static func isBlocked(_ standing: PinSet) -> Bool {
        inFront.contains { !standing.contains(pin: $0.front) && standing.isSuperset(of: $0.behind) }
    }
}
