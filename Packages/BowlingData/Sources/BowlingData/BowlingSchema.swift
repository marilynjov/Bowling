import SwiftData

/// The first schema version. Once phase 2 promotes it to CloudKit production, later
/// versions may only add entities and attributes, never rename or remove them.
enum BowlingSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Bowler.self, Session.self, Game.self, Frame.self, Roll.self,
            Ball.self, GamePhoto.self, BallPhoto.self, MaintenanceEvent.self,
            BowlingCenter.self, League.self, OilPattern.self,
        ]
    }
}

enum BowlingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [BowlingSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

/// The app's data store: one container, its main context, and the repositories over it.
@MainActor
public final class BowlingStore {
    nonisolated static var schema: Schema { Schema(versionedSchema: BowlingSchemaV1.self) }

    let container: ModelContainer
    let context: ModelContext

    public let bowlers: BowlerRepository
    public let balls: BallRepository
    public let sessions: SessionRepository
    public let games: GameRepository
    public let stats: StatsRepository

    /// - Parameter inMemory: An empty store that is never written to disk, for tests and previews.
    public init(inMemory: Bool = false) throws {
        container = try Self.makeContainer(inMemory: inMemory)
        context = container.mainContext
        context.autosaveEnabled = false
        bowlers = BowlerRepository(context: context)
        balls = BallRepository(context: context)
        sessions = SessionRepository(context: context)
        games = GameRepository(context: context)
        stats = StatsRepository(context: context)
        try backfillSyncFields()
    }

    /// Builds the container for user data. Sync stays off until phase 2 turns on CloudKit.
    /// - Parameter inMemory: Keeps the store in memory only, for tests and previews.
    nonisolated static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: BowlingMigrationPlan.self,
            configurations: configuration
        )
    }
}
