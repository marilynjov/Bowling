import BowlingCore

/// Turns scoresheet shorthand into `FrameRecord`s, so each demo game reads like a
/// scoresheet and its hand-computed score can be checked against it by eye.
///
/// countOnly, one character per roll: `X` strike, `/` spare, `-` zero, `F` foul,
/// `1`-`9` that many pins. Example frames: `"9/"`, `"X"`, `"81"`, `"XF9"`.
///
/// pinByPin, space-separated tokens per roll, each naming what stands after the roll:
/// `X` or `/` nothing, `7-10` those pins, `-` the same pins as before (nothing fell),
/// `F` a foul (the rack is respotted). Example frames: `"10 /"`, `"7-10 7"`, `"X 10 /"`.
///
/// A `^` suffix on any roll means it was thrown with `overrideBall`.
enum ScoresheetNotation {
    static func countOnlyFrames(_ frames: [String], overrideBall: DemoBall?) -> [FrameRecord] {
        frames.enumerated().map { offset, frame in
            var rack = Rack()
            let tokens = splitOverrides(frame.map(String.init))
            let rolls = tokens.enumerated().map { index, token in
                let count: Int
                switch token.symbol {
                case "X", "/": count = rack.standing.count
                case "-", "F": count = 0
                default: count = Int(token.symbol)!
                }
                // countOnly has no pin identities; knocking down any `count` pins keeps
                // the rack's standing count right.
                rack.roll(knocking: PinSet(pins: rack.standing.pins.prefix(count)))
                return RollRecord(
                    rollIndex: index + 1, pinCount: count, pinsKnown: false,
                    isFoul: token.symbol == "F", ballID: token.isOverride ? overrideBall?.id : nil
                )
            }
            return FrameRecord(frameIndex: offset + 1, rolls: rolls)
        }
    }

    static func pinByPinFrames(_ frames: [String], overrideBall: DemoBall?) -> [FrameRecord] {
        frames.enumerated().map { offset, frame in
            var rack = Rack()
            let tokens = splitOverrides(frame.split(separator: " ").map(String.init))
            let rolls = tokens.enumerated().map { index, token in
                let standingAfter: PinSet
                switch token.symbol {
                case "X", "/": standingAfter = []
                case "-", "F": standingAfter = rack.standing
                default: standingAfter = PinSet(pins: token.symbol.split(separator: "-").map { Int($0)! })
                }
                precondition(standingAfter.isSubset(of: rack.standing), "\(frame): \(token.symbol)")
                let knocked = rack.standing.subtracting(standingAfter)
                rack.roll(knocking: knocked)
                return RollRecord(
                    rollIndex: index + 1, pinsDown: knocked, pinCount: knocked.count,
                    pinsKnown: true, isFoul: token.symbol == "F",
                    ballID: token.isOverride ? overrideBall?.id : nil
                )
            }
            return FrameRecord(frameIndex: offset + 1, rolls: rolls)
        }
    }

    private struct Token {
        let symbol: String
        let isOverride: Bool
    }

    /// In countOnly `^` arrives as its own character after the roll it marks.
    private static func splitOverrides(_ raw: [String]) -> [Token] {
        raw.reduce(into: []) { tokens, piece in
            if piece == "^" {
                tokens[tokens.count - 1] = Token(symbol: tokens.last!.symbol, isOverride: true)
            } else if piece.hasSuffix("^") {
                tokens.append(Token(symbol: String(piece.dropLast()), isOverride: true))
            } else {
                tokens.append(Token(symbol: piece, isOverride: false))
            }
        }
    }

    /// Frame 10 racks reset after a strike, a spare, or two balls; a foul changes nothing.
    private struct Rack {
        var standing = PinSet.all
        var balls = 0

        mutating func roll(knocking knocked: PinSet) {
            standing.subtract(knocked)
            balls += 1
            if standing.isEmpty || balls == 2 {
                self = Rack()
            }
        }
    }
}
