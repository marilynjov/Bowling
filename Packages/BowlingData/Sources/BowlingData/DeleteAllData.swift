import SwiftData

extension BowlingStore {
    /// Settings "Delete all data": deletes every record, the owner included, so the app
    /// returns to first launch. From phase 2 the deletion syncs to every device on the
    /// iCloud account, so the confirmation must say so.
    public func deleteAllData() throws {
        func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
            for model in try context.fetch(FetchDescriptor<T>()) { context.delete(model) }
        }
        try context.write {
            for type in BowlingSchemaV1.models { try deleteAll(type) }
        }
    }
}
