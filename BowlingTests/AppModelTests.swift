import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct AppModelTests {
    let app: AppModel

    init() throws {
        app = AppModel(store: try BowlingStore(inMemory: true))
    }

    private func createOwner() throws -> BowlerRecord {
        try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
    }

    @Test func writeBumpsRevision() throws {
        #expect(app.revision == 0)
        let owner = try createOwner()
        #expect(owner.name == "Sam")
        #expect(app.revision == 1)
    }

    @Test func throwingWriteBumpsRevisionAndRethrows() {
        #expect(throws: RepositoryError.notFound) {
            try app.write { try $0.bowlers.updateOwner(name: "A", handedness: .right) }
        }
        #expect(app.revision == 1)
    }

    @Test func needsOnboardingUntilOwnerExists() throws {
        #expect(app.needsOnboarding)
        _ = try createOwner()
        #expect(!app.needsOnboarding)
    }

    @Test func needsOnboardingAfterDeleteAllData() throws {
        _ = try createOwner()
        #expect(!app.needsOnboarding)
        try app.write { try $0.deleteAllData() }
        #expect(app.needsOnboarding)
    }

    @Test func previewHasTheDemoOwner() {
        #expect(!AppModel.preview().needsOnboarding)
    }
}

/// The shared alert must come from the topmost view: iOS can't present an alert from a
/// view that is already presenting the Scoring cover.
@Suite struct ErrorPresenterTests {
    let app: AppModel

    init() throws {
        app = AppModel(store: try BowlingStore(inMemory: true))
    }

    struct Boom: Error {}

    @Test func noErrorShowsNowhere() {
        #expect(!app.showsError(in: .root))
        #expect(!app.showsError(in: .scoring))
    }

    @Test func errorWithScoringClosedShowsAtTheRoot() {
        app.error = Boom()
        #expect(app.showsError(in: .root))
        #expect(!app.showsError(in: .scoring))
    }

    @Test func errorWhileScoringShowsOnTheCover() {
        app.scoring = ScoringTarget(sessionID: SessionID(), gameID: GameID())
        app.error = Boom()
        #expect(!app.showsError(in: .root))
        #expect(app.showsError(in: .scoring))
    }
}
