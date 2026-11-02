#if DEBUG
import BowlingCore
import BowlingData
import Foundation

/// The `-uiTesting` launch: an in-memory store whose owner already exists, so UI tests start
/// on Home, and settings that start empty on every run. Debug builds only.
enum UITestLaunch {
    static let argument = "-uiTesting"
    static let suiteName = "com.marilynjov.bowling.uitesting"

    static func isActive(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(argument)
    }

    static func openStore() throws -> BowlingStore {
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
