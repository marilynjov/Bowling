import SwiftUI

/// Above the entry area while a finished frame is being fixed: which ball, and Cancel.
struct FrameEditBar: View {
    let model: ScoringModel
    let edit: FrameEdit

    var body: some View {
        HStack(spacing: 12) {
            Text("Editing frame \(edit.frameIndex) · ball \(edit.rollIndex)")
                .font(.headline)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Cancel", action: model.cancelEdit)
                .frame(minWidth: 48, minHeight: 48)
        }
        .padding(.horizontal, 12)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}
