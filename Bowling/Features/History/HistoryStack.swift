import SwiftUI

/// The History tab: the list, with session and game detail pushed on `app.historyPath`
/// (spec §6), so Home's recent rows can open a session here.
struct HistoryStack: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $app.historyPath) {
            HistoryScreen()
                .navigationDestination(for: HistoryRoute.self) { route in
                    switch route {
                    case .session(let id): SessionDetailScreen(id: id)
                    case .game(let id): GameDetailScreen(id: id)
                    }
                }
        }
    }
}

extension View {
    /// History's delete confirmation: asks `request.title`, then deletes through `app.delete`.
    /// A failed delete goes to the shared alert and leaves the screen as it was.
    func deleteConfirmation(_ request: Binding<DeleteRequest?>) -> some View {
        modifier(DeleteConfirmation(request: request))
    }
}

private struct DeleteConfirmation: ViewModifier {
    @Environment(AppModel.self) private var app
    @Binding var request: DeleteRequest?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            request?.title ?? "",
            isPresented: Binding(get: { request != nil }, set: { if !$0 { request = nil } }),
            titleVisibility: .visible,
            presenting: request
        ) { request in
            Button("Delete", role: .destructive) {
                do {
                    try app.delete(request)
                } catch {
                    app.error = error
                }
            }
        }
    }
}
