import BowlingCore
import SwiftUI

/// The night's bowlers in lineup order, shown with two or more: each name and score, the
/// current one highlighted and finished ones checked. Tapping one gives them the turn, for
/// someone bowling out of turn. Scrolls sideways instead of truncating.
struct BowlerStrip: View {
    let session: SessionScoringModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(session.bowlers.indices, id: \.self) { index in
                    chip(index)
                }
            }
            .padding(2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    @ViewBuilder private func chip(_ index: Int) -> some View {
        let model = session.bowlers[index]
        let isCurrent = index == session.currentIndex
        let isFinished = Rotation.isFinished(model.game)
        let button = Button { session.select(index) } label: {
            HStack(spacing: 6) {
                if isFinished { Image(systemName: "checkmark") }
                Text(model.bowlerName).lineLimit(1)
                Text("\(model.currentScore)").monospacedDigit()
            }
            .frame(minHeight: 48)
            .padding(.horizontal, 4)
        }
        .accessibilityLabel(AccessibilityText.bowlerChip(
            name: model.bowlerName, score: model.currentScore, isCurrent: isCurrent, isFinished: isFinished
        ))
        if isCurrent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}
