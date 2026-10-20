import SwiftUI

/// One typed score saved as a casual game today.
struct QuickScoreSheet: View {
    @Environment(AppModel.self) private var app
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Score", text: $text, prompt: Text("0"))
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .font(.scoreHero)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.ink)
                Text("Saved as a casual game today. You can change it in History.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.canvas)
            .navigationTitle("Quick score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { app.isQuickScoring = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(QuickScoreEntry.score(text) == nil)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }

    private func save() {
        guard let score = QuickScoreEntry.score(text) else { return }
        do {
            try app.quickScore(score)
        } catch {
            app.error = error
        }
    }
}

#if DEBUG
private struct QuickScoreSheetPreview: View {
    @State private var app = AppModel.preview()

    var body: some View {
        Color.canvas
            .sheet(isPresented: .constant(true)) { QuickScoreSheet() }
            .environment(app)
    }
}

#Preview("Light") { QuickScoreSheetPreview() }
#Preview("Dark") { QuickScoreSheetPreview().preferredColorScheme(.dark) }
#Preview("AX5") { QuickScoreSheetPreview().dynamicTypeSize(.accessibility5) }
#endif
