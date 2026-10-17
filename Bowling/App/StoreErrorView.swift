import SwiftUI

/// Shown when the store can't be opened at launch.
struct StoreErrorView: View {
    let error: any Error
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Your bowling data couldn't be opened", systemImage: "exclamationmark.triangle")
        } description: {
            Text(ErrorText.message(for: error))
        } actions: {
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

#if DEBUG
#Preview {
    struct DiskFull: LocalizedError {
        var errorDescription: String? { "There isn't enough space on this iPhone." }
    }
    return StoreErrorView(error: DiskFull(), retry: {})
}
#endif
