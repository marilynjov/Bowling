import SwiftUI

/// The real average, an arrow, and the average with every single-pin spare made, then the
/// gain. VoiceOver reads it as one element.
struct WhatIfCard: View {
    var content: WhatIfContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) { figures(arrow: "arrow.forward") }
                VStack(alignment: .leading, spacing: 8) { figures(arrow: "arrow.down") }
            }
            Text(content.detail)
                .font(.subheadline)
                .foregroundStyle(.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(content.sample)
                .font(.figure)
                .foregroundStyle(.inkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    /// `arrow.forward` side by side, so it mirrors right to left; `arrow.down` when stacked.
    @ViewBuilder private func figures(arrow: String) -> some View {
        figure(content.actual, caption: String(localized: "Your average"))
        Image(systemName: arrow)
            .foregroundStyle(.inkMuted)
        figure(content.allMade, caption: String(localized: "Every single pin made"))
    }

    private func figure(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.tileValue)
                .monospacedDigit()
                .foregroundStyle(.ink)
            Text(caption)
                .font(.figure)
                .foregroundStyle(.inkMuted)
        }
    }
}
