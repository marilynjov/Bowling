import BowlingCore
import SwiftUI

/// Ten frames in a horizontal scroll, each with its number, marks, and running total,
/// keeping the current frame in view (spec §7, Scoring). Finished frames are buttons when
/// `onSelectFrame` is set; History passes nil for a read-only strip.
struct ScorecardStrip: View {
    var scorecard: Scorecard
    var currentFrame: Int?
    var onSelectFrame: ((Int) -> Void)?

    init(scorecard: Scorecard, currentFrame: Int?, onSelectFrame: ((Int) -> Void)? = nil) {
        self.scorecard = scorecard
        self.currentFrame = currentFrame
        self.onSelectFrame = onSelectFrame
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(scorecard.frames, id: \.frameIndex) { frame in
                        cell(for: frame).id(frame.frameIndex)
                    }
                }
                .padding(2)
            }
            .onAppear { scroll(proxy, animated: false) }
            .onChange(of: currentFrame) { scroll(proxy, animated: true) }
        }
    }

    @ViewBuilder private func cell(for frame: FrameScore) -> some View {
        let isCurrent = frame.frameIndex == currentFrame
        if let onSelectFrame, !frame.marks.isEmpty, !isCurrent {
            Button { onSelectFrame(frame.frameIndex) } label: {
                FrameCell(frame: frame, isCurrent: false)
            }
            .buttonStyle(.plain)
        } else {
            FrameCell(frame: frame, isCurrent: isCurrent)
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let currentFrame else { return }
        if animated {
            withAnimation { proxy.scrollTo(currentFrame, anchor: .center) }
        } else {
            proxy.scrollTo(currentFrame, anchor: .center)
        }
    }
}

private struct FrameCell: View {
    var frame: FrameScore
    var isCurrent: Bool

    @ScaledMetric(relativeTo: .body) private var frameWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var tenthWidth: CGFloat = 62

    private var width: CGFloat { frame.frameIndex == 10 ? tenthWidth : frameWidth }

    var body: some View {
        let boxes = FrameText.boxes(for: frame)
        let splitBox = FrameText.splitBox(for: frame)
        VStack(spacing: 0) {
            Text("\(frame.frameIndex)")
                .font(.figure)
                .foregroundStyle(.inkMuted)
                .padding(.vertical, 3)
            HStack(spacing: 0) {
                ForEach(boxes.indices, id: \.self) { index in
                    MarkBox(mark: boxes[index], isSplit: index == splitBox)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 3)
            .background(.surface)
            .overlay(alignment: .top) { Rectangle().fill(.hairline).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(.hairline).frame(height: 1) }
            Text(FrameText.total(for: frame).isEmpty ? " " : FrameText.total(for: frame))
                .font(.frameTotal)
                .monospacedDigit()
                .foregroundStyle(.ink)
                .padding(.vertical, 5)
        }
        .frame(width: width)
        .background(.inset, in: .rect(cornerRadius: 8))
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 8).stroke(.accent, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.frame(frame))
    }
}

private struct MarkBox: View {
    var mark: Mark?
    var isSplit: Bool

    var body: some View {
        Text(mark.map(FrameText.symbol(for:)) ?? " ")
            .font(.frameMark)
            .foregroundStyle(mark.map { Color(Theme.color(for: $0)) } ?? Color(.ink))
            .lineLimit(1)
            .padding(2)
            .background {
                if isSplit {
                    Circle().stroke(.cautionText, lineWidth: 1.5)
                }
            }
    }
}

#if DEBUG
import BowlingFixtures

private struct ScorecardStripPreview: View {
    private let inProgress = PreviewData.game(.practiceInProgress)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("In progress").monoLabel()
            ScorecardStrip(
                scorecard: Scorer.scorecard(for: inProgress),
                currentFrame: Scorer.nextRoll(in: inProgress)?.frameIndex,
                onSelectFrame: { _ in }
            )
            Text("Perfect game").monoLabel()
            ScorecardStrip(scorecard: PreviewData.scorecard(.tournament1), currentFrame: nil)
            Text("All spares").monoLabel()
            ScorecardStrip(scorecard: PreviewData.scorecard(.earlyLeague1), currentFrame: nil)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.canvas)
    }
}

#Preview("Strip, light") { ScorecardStripPreview().preferredColorScheme(.light) }
#Preview("Strip, dark") { ScorecardStripPreview().preferredColorScheme(.dark) }
#Preview("Strip, AX3") { ScorecardStripPreview().dynamicTypeSize(.accessibility3) }
#endif
