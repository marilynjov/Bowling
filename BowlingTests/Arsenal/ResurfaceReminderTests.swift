import BowlingCore
import BowlingData
import Foundation
import Testing
@testable import Bowling

/// Records what `ResurfaceReminder` asks of the notification center.
final class FakeReminderCenter: ReminderCenter {
    var authorizationRequests = 0
    var added: [ResurfaceNotification] = []
    var cancelled: [String] = []

    func requestAuthorization() { authorizationRequests += 1 }
    func add(_ notification: ResurfaceNotification) { added.append(notification) }
    func cancel(ids: [String]) { cancelled += ids }
}

@Suite struct ResurfaceReminderTests {
    let center = FakeReminderCenter()
    let app: AppModel
    let owner: BowlerRecord

    init() throws {
        app = AppModel(store: try BowlingStore(inMemory: true), reminderCenter: center)
        owner = try app.write { try $0.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league) }
    }

    private func addBall(interval: Int?) throws -> BallID {
        try app.write {
            try $0.balls.addBall(BallFields(name: "Phaze", weightPounds: 15, resurfaceIntervalGames: interval)).id
        }
    }

    /// One game with `ball` as default, as Scoring's start writes it, a minute ago unless
    /// `date` says otherwise.
    private func bowl(_ ball: BallID, at date: Date = .now.addingTimeInterval(-60)) throws {
        _ = try app.write {
            try $0.sessions.startSession(
                SessionMetadata(date: date, eventType: .league),
                bowlers: [(bowlerID: owner.id, defaultBallID: ball)], entryMode: .finalOnly
            )
        }
    }

    @Test func gameThatCrossesTheIntervalSchedulesOneNotification() throws {
        let ball = try addBall(interval: 2)
        try bowl(ball)
        #expect(center.added.isEmpty)

        try bowl(ball)
        let notification = try #require(center.added.first)
        #expect(center.added.count == 1)
        #expect(notification.id == ResurfaceReminder.requestID(ball))
        #expect(notification.title == "Time to resurface Phaze")
        #expect(notification.body == "2 of 2 games since resurface")
        #expect(app.store.balls.activeBalls().first?.isResurfaceDue == true)

        // Still due after another game: no second notification.
        try bowl(ball)
        #expect(center.added.count == 1)
    }

    @Test func firesAtNineTheNextMorning() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 21, minute: 30)))
        let store = try BowlingStore(inMemory: true)
        let reminder = ResurfaceReminder(store: store, center: center, calendar: calendar, now: { now })
        let owner = try store.bowlers.createOwner(name: "Sam", handedness: .right, statsProfile: .league)
        let ball = try store.balls.addBall(BallFields(name: "Phaze", weightPounds: 15, resurfaceIntervalGames: 1)).id
        _ = try store.sessions.startSession(
            SessionMetadata(date: now.addingTimeInterval(-60), eventType: .league),
            bowlers: [(bowlerID: owner.id, defaultBallID: ball)], entryMode: .finalOnly
        )

        reminder.update(from: store)

        let fire = try #require(center.added.first?.fireDate)
        #expect(fire.year == 2027)
        #expect(fire.month == 1)
        #expect(fire.day == 1)
        #expect(fire.hour == 9)
        #expect(fire.minute == 0)
    }

    @Test func ballAlreadyDueAtLaunchSchedulesNothing() throws {
        let ball = try addBall(interval: 1)
        try bowl(ball)
        let relaunched = FakeReminderCenter()
        let app = AppModel(store: self.app.store, reminderCenter: relaunched)
        _ = try app.write { try $0.balls.addBall(BallFields(name: "Spare", weightPounds: 14)) }
        #expect(relaunched.added.isEmpty)
    }

    @Test func resurfaceWithdrawsThePendingNotification() throws {
        let ball = try addBall(interval: 1)
        try bowl(ball, at: .now.addingTimeInterval(-3_600))
        #expect(center.added.count == 1)

        app.loggingMaintenance = ball
        try app.logMaintenance(MaintenanceDraft(kind: .resurface, date: .now.addingTimeInterval(-1_800)))

        #expect(center.cancelled == [ResurfaceReminder.requestID(ball)])
        // Due again after the next game: a fresh notification.
        try bowl(ball)
        #expect(center.added.count == 2)
    }

    @Test func retiringWithdrawsThePendingNotification() throws {
        let ball = try addBall(interval: 1)
        try bowl(ball)
        try app.write { try $0.balls.setRetired(true, for: ball) }
        #expect(center.cancelled == [ResurfaceReminder.requestID(ball)])
    }

    @Test func savingABallWithAnIntervalAsksForPermission() throws {
        var form = BallForm()
        form.name = "Phaze"
        form.weightPounds = 15
        app.ballForm = .add
        try app.saveBall(form)
        #expect(center.authorizationRequests == 0)

        form.name = "Hy-Road"
        form.resurfaceInterval = "60"
        app.ballForm = .add
        try app.saveBall(form)
        #expect(center.authorizationRequests == 1)
    }
}
