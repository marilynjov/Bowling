#if DEBUG
import BowlingCore
import BowlingData
import Foundation

/// The `-uiTesting` launch: an in-memory store whose owner already exists, so UI tests start
/// on Home, and settings that start empty on every run. With `-demoStore` too, the store is
/// the previews' demo data instead (balls, sessions, maintenance), for checking a screen by
/// hand on any simulator. Debug builds only.
enum UITestLaunch {
    static let argument = "-uiTesting"
    static let demoArgument = "-demoStore"
    static let suiteName = "com.marilynjov.bowling.uitesting"

    static func isActive(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(argument)
    }

    static func openStore() throws -> BowlingStore {
        if ProcessInfo.processInfo.arguments.contains(demoArgument) { return try BowlingStore.demo() }
        let store = try BowlingStore(inMemory: true)
        _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        return store
    }

    /// Cleared first, so nothing a previous run remembered carries over.
    static func defaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
#endif
