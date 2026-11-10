import SwiftUI

/// "Resurface due" on an Arsenal row and ball detail (spec §7).
struct ResurfaceDueBadge: View {
    var body: some View {
        Text("Resurface due")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.cautionText)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.cautionSoft, in: .capsule)
    }
}
