import CoreGraphics

/// How the deck draws its pins: flat circles, or the drawn pins standing on spots.
enum PinDeckStyle: Sendable {
    case circles
    case pins
}

/// Where each pin sits in the triangle for a given width, from the back row (7-10) at the
/// top to the head pin at the bottom. Shared by `PinDeckView` and `LeaveDiagramView`, so
/// it enforces no minimum size; the deck's 48 pt floor comes from the phone's width.
///
/// Both styles put every pin at the same x, so a finger lands on the same pin in either.
/// The pins style squashes the rows (perspective) and stands each pin on its spot, the
/// front rows overlapping the ones behind, as in the drawing the art was cut from.
struct PinDeckLayout {
    static let rows: [[Int]] = [[7, 8, 9, 10], [4, 5, 6], [2, 3], [1]]

    let width: CGFloat
    let style: PinDeckStyle
    /// Center to center along a row.
    let spacing: CGFloat
    /// The circle's diameter (circles style).
    let pinDiameter: CGFloat

    init(width: CGFloat, style: PinDeckStyle = .circles) {
        self.width = width
        self.style = style
        spacing = width / 4
        pinDiameter = spacing * 0.78
    }

    // Proportions of the drawing, measured against its pin spacing.
    private var pinSize: CGSize { CGSize(width: spacing * 0.52, height: spacing * 1.35) }
    /// How far a pin's base sits below its spot's center.
    private var baseDrop: CGFloat { spacing * 0.05 }
    var spotSize: CGSize { CGSize(width: spacing * 0.41, height: spacing * 0.27) }

    private var rowStep: CGFloat {
        switch style {
        case .circles: spacing * 0.866
        case .pins: spacing * 0.75
        }
    }

    /// The first row's y: room for a circle, or for a back-row pin standing above its spot.
    private var firstRowY: CGFloat {
        switch style {
        case .circles: pinDiameter / 2
        case .pins: pinSize.height - baseDrop
        }
    }

    var height: CGFloat {
        switch style {
        case .circles: 3 * rowStep + pinDiameter
        case .pins: firstRowY + 3 * rowStep + max(spotSize.height / 2, baseDrop)
        }
    }

    /// The circle's center, or the spot's center in the pins style.
    func center(of pin: Int) -> CGPoint {
        guard let row = Self.rows.firstIndex(where: { $0.contains(pin) }),
              let column = Self.rows[row].firstIndex(of: pin) else { return .zero }
        let count = CGFloat(Self.rows[row].count)
        let x = width / 2 + (CGFloat(column) - (count - 1) / 2) * spacing
        let y = firstRowY + CGFloat(row) * rowStep
        return CGPoint(x: x, y: y)
    }

    /// Where the drawn pin stands (pins style): its base just below its spot.
    func pinFrame(of pin: Int) -> CGRect {
        let spot = center(of: pin)
        let size = pinSize
        return CGRect(x: spot.x - size.width / 2, y: spot.y + baseDrop - size.height,
                      width: size.width, height: size.height)
    }

    /// What a finger can touch for `pin` (pins style): the whole body, widened to most of
    /// the gap so thin pins stay easy to hit, down to the bottom of the spot.
    func hitArea(of pin: Int) -> CGRect {
        let body = pinFrame(of: pin)
        let spotBottom = center(of: pin).y + spotSize.height / 2
        let hitWidth = spacing * 0.9
        return CGRect(x: body.midX - hitWidth / 2, y: body.minY,
                      width: hitWidth, height: max(body.maxY, spotBottom) - body.minY)
    }

    /// The pin under `point`, or nil in the gaps. In the pins style the front rows are
    /// drawn over the back ones, so they are tested first.
    func pin(at point: CGPoint) -> Int? {
        switch style {
        case .circles:
            return (1...10).first { pin in
                let c = center(of: pin)
                return hypot(point.x - c.x, point.y - c.y) <= pinDiameter / 2
            }
        case .pins:
            return Self.rows.reversed().joined().first { hitArea(of: $0).contains(point) }
        }
    }
}
