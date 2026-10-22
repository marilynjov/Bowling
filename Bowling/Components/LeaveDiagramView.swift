import BowlingCore
import SwiftUI

/// A small, non-interactive pin deck showing what a first ball left: standing pins filled,
/// down pins outlined, splits in amber, and the leave's name beneath with a Split or
/// Washout tag under it (spec §7, "Leave diagrams"). Neither line wraps, so a long name
/// widens the view instead. VoiceOver reads it as one element.
struct LeaveDiagramView: View {
    enum Size {
        case small, regular

        var deckWidth: CGFloat {
            switch self {
            case .small: 44
            case .regular: 72
            }
        }
    }

    var leave: Leave
    var size: Size = .regular

    private var layout: PinDeckLayout { PinDeckLayout(width: size.deckWidth) }
    private var standingColor: Color { leave.kind == .split ? Color(.caution) : Color(.pinStanding) }

    private var tag: LocalizedStringKey? {
        if leave.kind == .split { return "Split" }
        if leave.isWashout { return "Washout" }
        return nil
    }

    var body: some View {
        VStack(spacing: 4) {
            deck
            Text(leave.name)
                .font(.figure)
                .foregroundStyle(.ink)
                .fixedSize()
            if let tag {
                Text(tag)
                    .font(.figure.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.cautionText)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.cautionSoft, in: .rect(cornerRadius: 6))
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.leave(leave))
    }

    private var deck: some View {
        let layout = layout
        return ZStack(alignment: .topLeading) {
            ForEach(1...10, id: \.self) { pin in
                let c = layout.center(of: pin)
                Group {
                    if leave.pins.contains(pin: pin) {
                        Circle().fill(standingColor)
                    } else {
                        Circle().stroke(.pinOutline, lineWidth: 1)
                    }
                }
                .frame(width: layout.pinDiameter, height: layout.pinDiameter)
                .position(c)
            }
        }
        .frame(width: layout.width, height: layout.height)
    }
}

#if DEBUG
private struct LeaveDiagramPreview: View {
    private let leaves = [
        PreviewData.leave(3, 6, 10),
        PreviewData.leave(7, 10),
        PreviewData.leave(10),
        PreviewData.leave(1, 2, 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach([LeaveDiagramView.Size.regular, .small], id: \.self) { size in
                HStack(alignment: .top, spacing: 20) {
                    ForEach(leaves, id: \.self) { leave in
                        LeaveDiagramView(leave: leave, size: size)
                    }
                }
            }
        }
        .padding(16)
        .background(.surface, in: .rect(cornerRadius: 14))
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.canvas)
    }
}

#Preview("Leaves, light") { LeaveDiagramPreview().preferredColorScheme(.light) }
#Preview("Leaves, dark") { LeaveDiagramPreview().preferredColorScheme(.dark) }
#Preview("Leaves, AX3") { LeaveDiagramPreview().dynamicTypeSize(.accessibility3) }
#endif
