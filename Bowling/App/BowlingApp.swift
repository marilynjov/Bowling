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
            if loader.app != nil {
                Text("Loaded")
            } else if let failure = loader.failure {
                StoreErrorView(error: failure, retry: loader.load)
            }
        }
    }
}
