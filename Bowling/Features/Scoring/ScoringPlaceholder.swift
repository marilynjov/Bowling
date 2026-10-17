import SwiftUI

/// Placeholder until #8. Shown in the root's full-screen cover.
struct ScoringPlaceholder: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Text("Scoring, coming in #8")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                Button("Close", systemImage: "xmark", action: app.closeScoring)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .glassBackground(in: Circle())
                    .padding()
            }
    }
}

#if DEBUG
#Preview {
    ScoringPlaceholder()
        .environment(AppModel.preview())
}
#endif
