import BowlingCore
import SwiftUI

/// The finished game: its score, Summary once every bowler has finished, and Undo (or
/// Change score for a typed score).
struct GameCompletePanel: View {
    let model: ScoringModel
    let session: SessionScoringModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Game complete")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Text("\(model.scorecard.finalScore ?? model.game.finalScore)")
                .font(.scoreHero)
                .monospacedDigit()
                .foregroundStyle(Color.accentText)
            if session.allFinished {
                Button(action: session.showSummary) {
                    Text("Summary").frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
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
