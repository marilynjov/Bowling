import SwiftUI

@main struct BowlingApp: App {
    @State private var loader: StoreLoader

    init() {
        let loader = StoreLoader()
        loader.load()
        _loader = State(initialValue: loader)
    }

    var body: some Scene {
        WindowGroup {
            if let app = loader.app {
                RootView().environment(app)
            } else if let failure = loader.failure {
                StoreErrorView(error: failure, retry: loader.load)
            }
        }
    }
}
