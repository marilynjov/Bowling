import SwiftUI

/// "Saved 187" with Undo, for 5 seconds after a quick score. With VoiceOver it stays
/// until Undo or the next quick score, and is announced, since 5 seconds isn't enough to
/// reach it past the tiles.
struct UndoBanner: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    var saved: SavedQuickScore

    static func dismissDelay(voiceOver: Bool) -> Duration? {
        voiceOver ? nil : .seconds(5)
    }

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
            if voiceOver {
                AccessibilityNotification.Announcement(String(localized: "Saved \(saved.score). Undo available.")).post()
            }
            await app.dismissQuickScore(saved, after: Self.dismissDelay(voiceOver: voiceOver))
        }
    }
}
