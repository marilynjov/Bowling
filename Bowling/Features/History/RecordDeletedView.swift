import SwiftUI

/// A pushed History screen whose session or game no longer exists (spec §6): the message
/// and a way back to the list.
struct RecordDeletedView: View {
    @Environment(AppModel.self) private var app
    /// "This session was deleted." / "This game was deleted."
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.headline)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            Button("Back to History") { app.historyPath = [] }
                .buttonStyle(.bordered)
                .tint(.accentText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)
    }
}

#if DEBUG
#Preview("Light") { RecordDeletedView(message: "This game was deleted.").environment(AppModel.preview()) }
#Preview("Dark") {
    RecordDeletedView(message: "This game was deleted.")
        .environment(AppModel.preview())
        .preferredColorScheme(.dark)
}
#Preview("AX5") {
    RecordDeletedView(message: "This session was deleted.")
        .environment(AppModel.preview())
        .dynamicTypeSize(.accessibility5)
}
#endif
