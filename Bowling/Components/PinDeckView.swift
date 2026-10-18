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

    /// The touch in progress, so one drag never flips a pin back. Replaced when a touch
    /// starts somewhere new, because a drag iOS cancelled never reaches `onEnded`.
    @State private var drag: PinDeckDrag?

    /// Height over width, from the layout's own geometry.
    private static let heightRatio = PinDeckLayout(width: 1).height

    /// What the deck shows: a caller's stray unavailable pins are never drawn standing.
    private var shown: PinSet { standing.intersection(available) }

    var body: some View {
        GeometryReader { proxy in
            let layout = PinDeckLayout(width: proxy.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(1...10, id: \.self) { pin in
                    pinView(pin, diameter: layout.pinDiameter)
                        .position(layout.center(of: pin))
                }
            }
            .frame(width: proxy.size.width, height: layout.height)
            .contentShape(Rectangle())
            .gesture(drag(in: layout))
        }
        .aspectRatio(1 / Self.heightRatio, contentMode: .fit)
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

    @ViewBuilder private func pinView(_ pin: Int, diameter: CGFloat) -> some View {
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityText.pin(pin, standing: isStanding))
            .accessibilityAddTraits(isAvailable ? .isButton : [])
            .accessibilityAction {
                guard isAvailable else { return }
                var marking = PinMarking(available: available, standing: standing)
                marking.touch(pin)
                standing = marking.standing
            }
    }
}

#if DEBUG
private struct PinDeckPreview: View {
    var available: PinSet
    @State var standing: PinSet

    var body: some View {
        VStack(spacing: 12) {
            PinDeckView(available: available, standing: $standing)
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
#endif
