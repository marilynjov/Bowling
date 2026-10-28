import SwiftUI

/// The app's mark: the smiling ball and three pins, on a clear background so it sits on
/// any screen. It scales to the width it's given.
struct AppLogo: View {
    var body: some View {
        Image(.logo)
            .resizable()
            .scaledToFit()
            .accessibilityLabel("Bowling")
    }
}

#if DEBUG
private struct AppLogoPreview: View {
    var body: some View {
        AppLogo()
            .frame(maxWidth: 240)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvas)
    }
}

#Preview("Light") { AppLogoPreview() }
#Preview("Dark") { AppLogoPreview().preferredColorScheme(.dark) }
#endif
