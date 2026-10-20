import BowlingCore
import SwiftUI

/// The finished game: its score, Done, and Undo (or Change score for a typed score).
/// #95 replaces Done with the game summary.
struct GameCompletePanel: View {
    @Environment(AppModel.self) private var app
    let model: ScoringModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Game complete")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Text("\(model.scorecard.finalScore ?? model.game.finalScore)")
                .font(.scoreHero)
                .monospacedDigit()
                .foregroundStyle(Color.accentText)
            Button(action: app.closeScoring) {
                Text("Done").frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if model.game.entryMode == .finalOnly {
                Button { model.isEditingFinalScore = true } label: {
                    Text("Change score").frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
            } else if model.canUndo {
                Button(action: model.undo) {
                    Text("Undo").frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 24)
    }
}
