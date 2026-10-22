import BowlingCore
import CoreGraphics

/// One touch on the pin deck, from finger down to finger up. It tests every point along
/// the finger's path, not only the sampled touch locations, so a fast swipe across the
/// back row marks all four pins. `continues(start:available:)` tells the view when a
/// touch event belongs to a new gesture: iOS can cancel a drag without ending it (an edge
/// swipe, Control Center, a call), and the next touch must not reuse the old one.
struct PinDeckDrag {
    let start: CGPoint
    let available: PinSet
    private var marking: PinMarking
    private var last: CGPoint

    var standing: PinSet { marking.standing }

    init(start: CGPoint, available: PinSet, standing: PinSet, layout: PinDeckLayout) {
        self.start = start
        self.available = available
        marking = PinMarking(available: available, standing: standing)
        last = start
        touch(at: start, in: layout)
    }

    func continues(start: CGPoint, available: PinSet) -> Bool {
        start == self.start && available == self.available
    }

    mutating func move(to point: CGPoint, in layout: PinDeckLayout) {
        let step = max(layout.pinDiameter / 4, 1)
        let dx = point.x - last.x, dy = point.y - last.y
        let count = max(1, Int((hypot(dx, dy) / step).rounded(.up)))
        for index in 1...count {
            let t = CGFloat(index) / CGFloat(count)
            touch(at: CGPoint(x: last.x + dx * t, y: last.y + dy * t), in: layout)
        }
        last = point
    }

    private mutating func touch(at point: CGPoint, in layout: PinDeckLayout) {
        if let pin = layout.pin(at: point) { marking.touch(pin) }
    }
}
