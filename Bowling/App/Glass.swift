import SwiftUI

extension View {
    /// Liquid Glass in `shape` on iOS 26 and later, a thin material on iOS 18, so
    /// components never repeat the availability check.
    @ViewBuilder func glassBackground(in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.thinMaterial, in: shape)
        }
    }
}
