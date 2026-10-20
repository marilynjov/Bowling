import SwiftUI

/// "Saved 187" with Undo, for 5 seconds after a quick score.
struct UndoBanner: View {
    @Environment(AppModel.self) private var app
    var saved: SavedQuickScore

    var body: some View {
        HStack {
            Text("Saved \(saved.score)")
                .foregroundStyle(Color.ink)
            Spacer()
            Button("Undo") {
                do {
                    try app.undoQuickScore()
                } catch {
                    app.error = error
                }
            }
            .fontWeight(.semibold)
            .foregroundStyle(Color.accentText)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.surface, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.hairline))
        .accessibilityElement(children: .contain)
        // A newer quick score restarts the timer; an undone one is already gone.
        .task(id: saved) {
            try? await Task.sleep(for: .seconds(5))
            if app.savedQuickScore == saved { app.savedQuickScore = nil }
        }
    }
}
