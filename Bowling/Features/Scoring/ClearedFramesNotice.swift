import SwiftUI

/// "Frames 4 and 5 were cleared. Enter them again." after an edit dropped later frames.
/// VoiceOver announces it.
struct ClearedFramesNotice: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(.subheadline)
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
            .onAppear(perform: announce)
            .onChange(of: text, announce)
    }

    private func announce() {
        AccessibilityNotification.Announcement(text).post()
    }
}
