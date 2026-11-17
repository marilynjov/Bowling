import BowlingCore
import BowlingData
import Foundation
import UserNotifications

/// Spec §7 "Resurface reminder": when a write makes an active ball due for a resurface, a
/// local notification for 9:00 the next morning, when the bowler is away from the lanes and
/// can plan it. When a ball stops being due (resurfaced, retired, interval raised, deleted),
/// its pending notification is withdrawn.
///
/// Only a change counts: a ball already due at launch, or still due after another game,
/// schedules nothing, so the bowler hears about each crossing once.
final class ResurfaceReminder {
    private let center: any ReminderCenter
    private let calendar: Calendar
    private let now: () -> Date
    /// The balls due after the last write.
    private var due: Set<BallID>

    init(store: BowlingStore, center: any ReminderCenter = SystemReminderCenter(),
         calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = { .now }) {
        self.center = center
        self.calendar = calendar
        self.now = now
        due = Set(store.balls.activeBalls().filter(\.isResurfaceDue).map(\.id))
    }

    /// Asks for notification permission. iOS shows the prompt only the first time, so the
    /// ball form calls this on every save with an interval set.
    func requestAuthorization() {
        center.requestAuthorization()
    }

    /// Run after every write: schedules balls that just became due and withdraws balls
    /// that stopped being due.
    func update(from store: BowlingStore) {
        let balls = store.balls.activeBalls().filter(\.isResurfaceDue)
        let current = Set(balls.map(\.id))
        let cleared = due.subtracting(current)
        if !cleared.isEmpty {
            center.cancel(ids: cleared.map(Self.requestID))
        }
        for ball in balls where !due.contains(ball.id) {
            guard let maintenance = try? store.balls.maintenance(for: ball.id),
                  let interval = maintenance.resurfaceIntervalGames else { continue }
            center.add(ResurfaceNotification(
                id: Self.requestID(ball.id),
                title: String(localized: "Time to resurface \(ball.name)"),
                body: String(localized: "\(maintenance.gamesSinceResurface) of \(interval) games since resurface"),
                fireDate: fireDate()
            ))
        }
        due = current
    }

    /// 9:00 tomorrow in the bowler's calendar.
    private func fireDate() -> DateComponents {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now())) ?? now()
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 0
        return components
    }

    static func requestID(_ ball: BallID) -> String {
        "resurface.\(ball.uuidString)"
    }
}

/// One scheduled resurface notification.
struct ResurfaceNotification: Hashable {
    var id: String
    var title: String
    var body: String
    /// Calendar fields of the fire time, matched once.
    var fireDate: DateComponents
}

/// The notification calls `ResurfaceReminder` makes; tests pass a fake.
protocol ReminderCenter {
    func requestAuthorization()
    /// Replaces a pending notification with the same ID.
    func add(_ notification: ResurfaceNotification)
    func cancel(ids: [String])
}

struct SystemReminderCenter: ReminderCenter {
    private var center: UNUserNotificationCenter { .current() }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Without permission iOS drops the request, which is what the bowler chose.
    func add(_ notification: ResurfaceNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: notification.fireDate, repeats: false)
        center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger))
    }

    func cancel(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
