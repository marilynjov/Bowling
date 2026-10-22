import BowlingCore

/// What each box of a scorecard frame shows. Plain Swift so the rules are unit tested;
/// `ScorecardStrip` only draws the result.
enum FrameText {
    static func symbol(for mark: Mark) -> String {
        switch mark {
        case .strike: "X"
        case .spare: "/"
        case .foul: "F"
        case .gutter: "-"
        case .count(let pins): "\(pins)"
        }
    }

    /// Two boxes for frames 1 to 9, three for the 10th; nil is an empty box. A strike in
    /// frames 1 to 9 sits in the second box, as on a lane monitor.
    static func boxes(for frame: FrameScore) -> [Mark?] {
        if frame.frameIndex == 10 {
            return padded(frame.marks, to: 3)
        }
        if frame.marks == [.strike] {
            return [nil, .strike]
        }
        return padded(frame.marks, to: 2)
    }

    /// The box holding the first ball of a split leave, which gets the split circle. In
    /// the 10th a leave can follow a strike, so it is the box after the leading strikes.
    static func splitBox(for frame: FrameScore) -> Int? {
        guard frame.leave?.kind == .split else { return nil }
        guard frame.frameIndex == 10 else { return 0 }
        return frame.marks.prefix { $0 == .strike }.count
    }

    /// Blank until the frame's running total is known.
    static func total(for frame: FrameScore) -> String {
        frame.runningTotal.map(String.init) ?? ""
    }

    private static func padded(_ marks: [Mark], to count: Int) -> [Mark?] {
        let boxes = marks.prefix(count).map { Optional($0) }
        return boxes + Array(repeating: nil, count: count - boxes.count)
    }
}
