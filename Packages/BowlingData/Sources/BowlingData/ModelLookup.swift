import Foundation
import SwiftData

// One fetch per model type: #Predicate cannot be written once over a generic `id` key path.
extension ModelContext {
    func bowler(_ id: UUID) throws -> Bowler {
        try first(FetchDescriptor<Bowler>(predicate: #Predicate { $0.id == id }))
    }

    func session(_ id: UUID) throws -> Session {
        try first(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id }))
    }

    func game(_ id: UUID) throws -> Game {
        try first(FetchDescriptor<Game>(predicate: #Predicate { $0.id == id }))
    }

    func ball(_ id: UUID) throws -> Ball {
        try first(FetchDescriptor<Ball>(predicate: #Predicate { $0.id == id }))
    }

    func center(_ id: UUID) throws -> BowlingCenter {
        try first(FetchDescriptor<BowlingCenter>(predicate: #Predicate { $0.id == id }))
    }

    func league(_ id: UUID) throws -> League {
        try first(FetchDescriptor<League>(predicate: #Predicate { $0.id == id }))
    }

    func oilPattern(_ id: UUID) throws -> OilPattern {
        try first(FetchDescriptor<OilPattern>(predicate: #Predicate { $0.id == id }))
    }

    private func first<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> T {
        var descriptor = descriptor
        descriptor.fetchLimit = 1
        guard let model = try fetch(descriptor).first else { throw RepositoryError.notFound }
        return model
    }

    /// Runs `body` and saves. If either throws, every pending change is discarded, so a
    /// refused or failed write never leaves half an edit for the next save to pick up.
    func write<T>(_ body: () throws -> T) throws -> T {
        do {
            let result = try body()
            try save()
            return result
        } catch {
            rollback()
            throw error
        }
    }

    /// Sync can deliver a second owner before the merge rule runs; until then every device
    /// uses the one the merge will keep: the oldest, ties broken by the smaller UUID string.
    func owner() -> Bowler? {
        let owners = (try? fetch(FetchDescriptor<Bowler>(predicate: #Predicate { $0.isOwner }))) ?? []
        return owners.min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }
}
