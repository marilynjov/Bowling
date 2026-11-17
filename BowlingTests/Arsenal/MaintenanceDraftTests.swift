import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

@Suite struct MaintenanceDraftTests {
    let app: AppModel
    let ball: BallID

    init() throws {
        app = AppModel(store: try BowlingStore(inMemory: true), reminderCenter: FakeReminderCenter())
        ball = try app.write {
            try $0.balls.addBall(BallFields(name: "Phaze", weightPounds: 15, surfaceGrit: "1500 Polished")).id
        }
    }

    @Test func resurfaceGritBecomesTheCurrentSurface() throws {
        app.loggingMaintenance = ball
        try app.logMaintenance(MaintenanceDraft(kind: .resurface, surfaceGrit: " 2000 Abralon ", notes: " Pro shop "))

        #expect(app.loggingMaintenance == nil)
        let event = try #require(try app.store.balls.maintenance(for: ball).events.first)
        #expect(event.kind == .resurface)
        #expect(event.surfaceGritAfter == "2000 Abralon")
        #expect(event.notes == "Pro shop")
        #expect(try app.store.balls.detail(for: ball).fields.surfaceGrit == "2000 Abralon")
    }

    @Test func otherKindsDropAGritTypedBeforeTheKindChanged() throws {
        #expect(!MaintenanceDraft(kind: .oilExtraction).takesGrit)
        app.loggingMaintenance = ball
        try app.logMaintenance(MaintenanceDraft(kind: .oilExtraction, surfaceGrit: "4000"))

        #expect(try app.store.balls.maintenance(for: ball).events.first?.surfaceGritAfter == "")
        #expect(try app.store.balls.detail(for: ball).fields.surfaceGrit == "1500 Polished")
    }

    @Test func pickerOffersEveryKnownKind() {
        #expect(Set(MaintenanceDraft.kinds) == Set(MaintenanceKind.allCases).subtracting([.unknown]))
    }

    @Test func secondSaveTapLogsNothing() throws {
        app.loggingMaintenance = ball
        try app.logMaintenance(MaintenanceDraft(kind: .polish))
        try app.logMaintenance(MaintenanceDraft(kind: .polish))
        #expect(try app.store.balls.maintenance(for: ball).events.count == 1)
    }

    @Test func refusedSaveKeepsTheSheet() throws {
        app.loggingMaintenance = ball
        #expect(throws: RepositoryError.invalidMaintenance(.dateInFuture)) {
            try app.logMaintenance(MaintenanceDraft(date: .now.addingTimeInterval(86_400)))
        }
        #expect(app.loggingMaintenance == ball)
    }
}
