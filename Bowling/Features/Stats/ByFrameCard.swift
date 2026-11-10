import BowlingCore
import Charts
import SwiftUI

/// Frames 1 to 10 as Accent bars on a fixed scale, 0–100% or 0–10 pins, so frames compare
/// honestly. VoiceOver reads each bar: "Frame 1, 25%".
struct ByFrameCard: View {
    var content: ByFrameContent
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart(content.bars, id: \.frame) { bar in
                BarMark(x: .value("Frame", String(bar.frame)), y: .value("Value", bar.value))
                    .foregroundStyle(Color.accent)
                    // The value over each bar, so 9.6 and 9.8 can be told apart on the
                    // fixed scale.
                    .annotation(position: .top, spacing: 2) {
                        Text(bar.annotation)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.inkMuted)
                    }
                    .accessibilityLabel(bar.accessibilityLabel)
                    .accessibilityValue("")
            }
            .chartYScale(domain: content.kind == .strikes ? 0...1 : 0...10)
            .chartYAxis {
                if content.kind == .strikes {
                    AxisMarks(values: [0, 0.5, 1]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let rate = value.as(Double.self) {
                                Text(rate.formatted(.percent.precision(.fractionLength(0)).locale(locale)))
                            }
                        }
                    }
                } else {
                    AxisMarks(values: [0, 5, 10])
                }
            }
            .frame(height: 160)
            // Room for the labels over full-height bars.
            .padding(.top, 8)
            // Ten frame labels and the axis can't grow past this and still fit; each bar's
            // VoiceOver label carries its value at any size.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            Text(content.sample)
                .font(.figure)
                .foregroundStyle(.inkMuted)
        }
    }
}
