import SwiftUI

@main struct BowlingApp: App {
    @State private var loader: StoreLoader

    init() {
        #if DEBUG
        let loader = UITestLaunch.isActive()
            ? StoreLoader(open: UITestLaunch.openStore, defaults: UITestLaunch.defaults())
            : StoreLoader()
        #else
        let loader = StoreLoader()
        #endif
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
