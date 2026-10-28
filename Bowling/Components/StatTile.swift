import BowlingCore
import SwiftUI

/// One stat with its sample size, as a D1 card: label, value, an optional progress bar for
/// rates, and the sample beneath. VoiceOver reads it as one element.
struct StatTile: View {
    /// Already localized, so the same text serves the label and VoiceOver.
    var title: String
    var value: String
    var sample: String?
    /// 0...1; rates show a bar, means don't.
    var progress: Double?
    /// A second line under the sample, such as Stats' "Last 10 201 · Last 30 195".
    var footnote: String?

    init(title: String, value: String, sample: String?, progress: Double? = nil, footnote: String? = nil) {
        self.title = title
        self.value = value
        self.sample = sample
        self.progress = progress
        self.footnote = footnote
    }

    init(_ content: StatTileContent, footnote: String? = nil) {
        self.init(title: content.title, value: content.value, sample: content.sample,
                  progress: content.progress, footnote: footnote)
    }

    init(title: String, rate: Rate, unit: StatFormat.Unit) {
        self.init(
            title: title, value: StatFormat.percent(rate),
            sample: StatFormat.sample(rate.attempts, unit), progress: rate.value
        )
    }

    init(title: String, mean: Mean) {
        self.init(title: title, value: StatFormat.average(mean), sample: StatFormat.sample(mean.count, .games))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).monoLabel()
            Text(value)
                .font(.tileValue)
                .monospacedDigit()
                .foregroundStyle(.ink)
            if let progress {
                ProgressBar(value: progress)
            }
            if let sample {
                Text(sample)
                    .font(.figure)
                    .foregroundStyle(.inkMuted)
            }
            if let footnote {
                Text(footnote)
                    .font(.figure)
                    .foregroundStyle(.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.surface, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.hairline))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.statTile(title: title, value: value, sample: sample)
            + (footnote.map { ", " + $0 } ?? ""))
    }
}

private struct ProgressBar: View {
    var value: Double

    var body: some View {
        Capsule()
            .fill(.inset)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.accent)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
    }
}

#if DEBUG
private struct StatTilePreview: View {
    private let report = PreviewData.report

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: String(localized: "Average"), mean: report.average)
                    StatTile(
                        title: String(localized: "High game"),
                        value: report.highGame.map { "\($0.score)" } ?? "–",
                        sample: report.highGame.map { $0.game.date.formatted(date: .abbreviated, time: .omitted) }
                    )
                    StatTile(title: String(localized: "Strike %"), rate: report.strikes, unit: .frames)
                    StatTile(title: String(localized: "Spare %"), rate: report.spares, unit: .chances)
                }
                StatTile(title: String(localized: "Spare %"), rate: Rate(hits: 0, attempts: 0), unit: .chances)
            }
            .padding(16)
        }
        .background(.canvas)
    }
}

#Preview("Tiles, light") { StatTilePreview().preferredColorScheme(.light) }
#Preview("Tiles, dark") { StatTilePreview().preferredColorScheme(.dark) }
#Preview("Tiles, AX3") { StatTilePreview().dynamicTypeSize(.accessibility3) }
#endif
