import CoreGraphics

/// Where each pin sits in the triangle for a given width, from the back row (7-10) at the
/// top to the head pin at the bottom. Shared by `PinDeckView` and `LeaveDiagramView`, so
/// it enforces no minimum size; the deck's 48 pt floor comes from the phone's width.
struct PinDeckLayout {
    static let rows: [[Int]] = [[7, 8, 9, 10], [4, 5, 6], [2, 3], [1]]

    let width: CGFloat
    /// Center to center, along a row and between rows' diagonals.
    let spacing: CGFloat
    let pinDiameter: CGFloat

    init(width: CGFloat) {
        self.width = width
        spacing = width / 4
        pinDiameter = spacing * 0.78
    }

    private var rowStep: CGFloat { spacing * 0.866 }

    var height: CGFloat { 3 * rowStep + pinDiameter }

    func center(of pin: Int) -> CGPoint {
        guard let row = Self.rows.firstIndex(where: { $0.contains(pin) }),
              let column = Self.rows[row].firstIndex(of: pin) else { return .zero }
        let count = CGFloat(Self.rows[row].count)
        let x = width / 2 + (CGFloat(column) - (count - 1) / 2) * spacing
        let y = pinDiameter / 2 + CGFloat(row) * rowStep
        return CGPoint(x: x, y: y)
    }

    /// The pin whose circle contains `point`, or nil in the gaps between pins.
    func pin(at point: CGPoint) -> Int? {
        (1...10).first { pin in
            let c = center(of: pin)
            return hypot(point.x - c.x, point.y - c.y) <= pinDiameter / 2
        }
    }
}
