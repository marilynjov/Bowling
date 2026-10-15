import SwiftUI

extension View {
    /// The shared alert for `app.error`. Applied to the root and to the Scoring cover's
    /// content; `AppModel.showsError(in:)` lets only the topmost one present it.
    func sharedErrorAlert(in presenter: ErrorPresenter) -> some View {
        modifier(SharedErrorAlert(presenter: presenter))
    }
}

private struct SharedErrorAlert: ViewModifier {
    @Environment(AppModel.self) private var app
    let presenter: ErrorPresenter

    func body(content: Content) -> some View {
        content.alert("Something went wrong", isPresented: isPresented) {
            Button("OK") { app.error = nil }
        } message: {
            if let error = app.error {
                Text(ErrorText.message(for: error))
            }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { app.showsError(in: presenter) }, set: { if !$0 { app.error = nil } })
    }
}
