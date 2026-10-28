import SwiftUI

/// The filter's chips above the cards; a tap opens the filter sheet.
struct StatsFilterBar: View {
    var chips: [String]
    var edit: () -> Void

    var body: some View {
        Button(action: edit) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        Text(chip)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.surface, in: .capsule)
                            .overlay(Capsule().stroke(.hairline))
                    }
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.accentText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
        .background(Color.canvas)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chips.joined(separator: ", "))
        .accessibilityHint("Edit filters")
        .accessibilityAddTraits(.isButton)
    }
}
