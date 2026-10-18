import BowlingCore
import SwiftUI

/// The ten-pin triangle for marking a roll (spec §7, Scoring). Tap toggles a pin; dragging
/// sets every pin the finger crosses to the first pin's new state (`PinDeckDrag`). Pins not
/// in `available` are down from an earlier roll: dimmed and untouchable. The deck fills
/// its width; on a phone that keeps pins at 48 pt or more.
///
/// Tap standing and tap fallen use the same deck: the caller starts `standing` empty or
/// equal to `available`.
struct PinDeckView: View {
    var available: PinSet
    @Binding var standing: PinSet
    var style: PinDeckStyle = .circles

    /// The touch in progress, so one drag never flips a pin back. Replaced when a touch
    /// starts somewhere new, because a drag iOS cancelled never reaches `onEnded`.
    @State private var drag: PinDeckDrag?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(available: PinSet, standing: Binding<PinSet>, style: PinDeckStyle = .circles) {
        self.available = available
        _standing = standing
        self.style = style
    }

    /// Height over width, from the layout's own geometry.
    private var heightRatio: CGFloat { PinDeckLayout(width: 1, style: style).height }

    /// What the deck shows: a caller's stray unavailable pins are never drawn standing.
    private var shown: PinSet { standing.intersection(available) }

    var body: some View {
        GeometryReader { proxy in
            let layout = PinDeckLayout(width: proxy.size.width, style: style)
            ZStack(alignment: .topLeading) {
                switch style {
                case .circles: circles(in: layout)
                case .pins: pins(in: layout)
                }
            }
            .frame(width: proxy.size.width, height: layout.height)
            .contentShape(Rectangle())
            .gesture(drag(in: layout))
        }
        .aspectRatio(1 / heightRatio, contentMode: .fit)
        .sensoryFeedback(.selection, trigger: standing)
        .onChange(of: available) { drag = nil }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AccessibilityText.deckSummary(standing: shown))
    }

    private func drag(in layout: PinDeckLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                var current = drag.flatMap { $0.continues(start: value.startLocation, available: available) ? $0 : nil }
                    ?? PinDeckDrag(start: value.startLocation, available: available, standing: standing, layout: layout)
                current.move(to: value.location, in: layout)
                drag = current
                if current.standing != standing {
                    standing = current.standing
                }
            }
            .onEnded { _ in drag = nil }
    }

    // MARK: Circles style

    private func circles(in layout: PinDeckLayout) -> some View {
        ForEach(1...10, id: \.self) { pin in
            circle(pin, diameter: layout.pinDiameter)
                .position(layout.center(of: pin))
        }
    }

    @ViewBuilder private func circle(_ pin: Int, diameter: CGFloat) -> some View {
        let isAvailable = available.contains(pin: pin)
        let isStanding = shown.contains(pin: pin)
        Text("\(pin)")
            .font(.pinNumber)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .foregroundStyle(isStanding ? Color(.onPinStanding) : Color(.inkMuted))
            .frame(width: diameter, height: diameter)
            .background {
                if isStanding {
                    Circle().fill(.pinStanding)
                } else {
                    Circle().stroke(.pinOutline, lineWidth: 1.5)
                }
            }
            .opacity(isAvailable ? 1 : 0.35)
            .modifier(PinAccessibility(pin: pin, isAvailable: isAvailable, isStanding: isStanding, toggle: toggle))
    }

    // MARK: Pins style

    /// Spots underneath, then the pins from the back row forward so front pins overlap,
    /// then one invisible element per pin for VoiceOver over its whole tap area.
    @ViewBuilder private func pins(in layout: PinDeckLayout) -> some View {
        let order = Array(PinDeckLayout.rows.joined())
        ForEach(order, id: \.self) { pin in
            spot(pin, size: layout.spotSize)
                .position(layout.center(of: pin))
        }
        ZStack(alignment: .topLeading) {
            ForEach(order, id: \.self) { pin in
                if shown.contains(pin: pin) {
                    let frame = layout.pinFrame(of: pin)
                    drawnPin(pin, size: frame.size)
                        .position(x: frame.midX, y: frame.midY)
                        .transition(pinTransition(for: pin, height: frame.height))
                }
            }
        }
        .frame(width: layout.width, height: layout.height, alignment: .topLeading)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.3), value: shown)
        ForEach(order, id: \.self) { pin in
            let area = layout.hitArea(of: pin)
            Color.clear
                .frame(width: area.width, height: area.height)
                .position(x: area.midX, y: area.midY)
                .allowsHitTesting(false)
                .modifier(PinAccessibility(
                    pin: pin, isAvailable: available.contains(pin: pin),
                    isStanding: shown.contains(pin: pin), toggle: toggle
                ))
        }
    }

    private func spot(_ pin: Int, size: CGSize) -> some View {
        Image(.pinSpot)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(.pinOutline)
            .frame(width: size.width, height: size.height)
            .overlay {
                // The pin covers its spot while standing; only a down pin's number shows.
                Text("\(pin)")
                    .opacity(shown.contains(pin: pin) ? 0 : 1)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(.onPinStanding)
                    .environment(\.colorScheme, .light)
            }
            .opacity(available.contains(pin: pin) ? 1 : 0.35)
            .accessibilityHidden(true)
    }

    /// The pin art is white in both appearances, so its number always uses the light
    /// appearance's Ink.
    private func drawnPin(_ pin: Int, size: CGSize) -> some View {
        Image(.pinArt)
            .resizable()
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .bottom) {
                Text("\(pin)")
                    .font(.pinNumber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(.ink)
                    .environment(\.colorScheme, .light)
                    .frame(width: size.width * 0.8)
                    .padding(.bottom, size.height * 0.2)
            }
            .accessibilityHidden(true)
    }

    /// Knocked down, a pin tips away from the middle of the deck and slides back as it
    /// fades, like real pin action; the head pin and 5 pin fall straight back. Stood back
    /// up, it pops up from its spot. Reduce Motion gets a plain fade.
    private func pinTransition(for pin: Int, height: CGFloat) -> AnyTransition {
        if reduceMotion { return .opacity }
        let direction: CGFloat = [7, 8, 4, 2].contains(pin) ? -1 : [9, 10, 6, 3].contains(pin) ? 1 : 0
        return .asymmetric(
            insertion: .scale(scale: 0.7, anchor: .bottom).combined(with: .opacity),
            removal: .modifier(
                active: PinFall(progress: 1, direction: direction, height: height),
                identity: PinFall(progress: 0, direction: direction, height: height)
            )
        )
    }

    private func toggle(_ pin: Int) {
        var marking = PinMarking(available: available, standing: standing)
        marking.touch(pin)
        standing = marking.standing
    }
}

/// One pin's VoiceOver element: a button that toggles it, or static text when it's down
/// from an earlier roll.
private struct PinAccessibility: ViewModifier {
    var pin: Int
    var isAvailable: Bool
    var isStanding: Bool
    var toggle: (Int) -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityText.pin(pin, standing: isStanding))
            .accessibilityAddTraits(isAvailable ? .isButton : [])
            .accessibilityAction {
                guard isAvailable else { return }
                toggle(pin)
            }
    }
}

/// A pin falling over: at `progress` 1 it has tipped about 80° to `direction` (-1 left,
/// 1 right) around its base and slid back, or for `direction` 0 fallen straight back.
private struct PinFall: ViewModifier {
    var progress: CGFloat
    var direction: CGFloat
    var height: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: direction == 0 ? 1 - 0.65 * progress : 1, anchor: .bottom)
            .rotationEffect(.degrees(80 * direction * progress), anchor: .bottom)
            .offset(x: direction * height * 0.12 * progress, y: -height * 0.1 * progress)
            .opacity(1 - progress)
    }
}

#if DEBUG
private struct PinDeckPreview: View {
    var available: PinSet
    @State var standing: PinSet
    var style: PinDeckStyle = .circles

    var body: some View {
        VStack(spacing: 12) {
            PinDeckView(available: available, standing: $standing, style: style)
            Text(AccessibilityText.deckSummary(standing: standing))
                .font(.figure)
                .foregroundStyle(.inkMuted)
        }
        .padding(14)
        .background(.surface, in: .rect(cornerRadius: 14, style: .continuous))
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.canvas)
    }
}

#Preview("Fresh rack, light") { PinDeckPreview(available: .all, standing: []).preferredColorScheme(.light) }
#Preview("Fresh rack, dark") { PinDeckPreview(available: .all, standing: []).preferredColorScheme(.dark) }
#Preview("Second ball, 3-6-10") {
    PinDeckPreview(available: PinSet(pins: [3, 6, 10]), standing: PinSet(pins: [3, 6, 10]))
}
#Preview("All down") { PinDeckPreview(available: [], standing: []) }
#Preview("Fresh rack, AX3") { PinDeckPreview(available: .all, standing: []).dynamicTypeSize(.accessibility3) }
#Preview("Pins, full rack") { PinDeckPreview(available: .all, standing: .all, style: .pins) }
#Preview("Pins, full rack, dark") {
    PinDeckPreview(available: .all, standing: .all, style: .pins).preferredColorScheme(.dark)
}
#Preview("Pins, second ball, 3-6-10") {
    PinDeckPreview(available: PinSet(pins: [3, 6, 10]), standing: PinSet(pins: [3, 6, 10]), style: .pins)
}
#Preview("Pins, AX3") {
    PinDeckPreview(available: .all, standing: .all, style: .pins).dynamicTypeSize(.accessibility3)
}
#endif
