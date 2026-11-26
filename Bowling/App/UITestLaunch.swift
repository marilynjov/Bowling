#if DEBUG
import BowlingCore
import BowlingData
import Foundation

/// The `-uiTesting` launch: an in-memory store whose owner already exists, so UI tests start
/// on Home, and settings that start empty on every run. Debug builds only.
enum UITestLaunch {
    static let argument = "-uiTesting"
    /// With `-uiTesting`: keep the store on disk between launches, so a test can relaunch the
    /// app and find what it saved. Without it the store is in memory and starts fresh.
    static let persistentArgument = "-persistentStore"
    static let suiteName = "com.marilynjov.bowling.uitesting"

    static func isActive(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(argument)
    }

    static func isPersistent(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(persistentArgument)
    }

    static func openStore() throws -> BowlingStore {
        try openStore(persistent: isPersistent())
    }

    static func openStore(persistent: Bool) throws -> BowlingStore {
        let store = persistent ? try BowlingStore() : try BowlingStore(inMemory: true)
        if store.bowlers.owner() == nil {
            _ = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        }
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
