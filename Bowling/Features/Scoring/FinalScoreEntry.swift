import BowlingCore
import SwiftUI

/// A final-only game's typed score: 0 through 300, the Quick score rule. Prefilled when
/// changing a saved score.
struct FinalScoreEntry: View {
    let model: ScoringModel
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            TextField("Score", text: $text, prompt: Text("0"))
                .keyboardType(.numberPad)
                .focused($focused)
                .font(.scoreHero)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ink)
            Button { model.saveFinalScore(text) } label: {
                Text("Save").frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(QuickScoreEntry.score(text) == nil)
        }
        .onAppear {
            if model.isEditingFinalScore { text = String(model.game.finalScore) }
            focused = true
        }
    }
}
