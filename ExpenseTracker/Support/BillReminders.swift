import Foundation
import UserNotifications

struct BillReminderPlan: Equatable {
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
}

enum BillReminderPlanner {
    static let identifierPrefix = "ledgerleaf.bill."

    static func plans(for schedules: [RecurringTransaction], now: Date = .now, calendar: Calendar = .current) -> [BillReminderPlan] {
        schedules.compactMap { schedule in
            guard schedule.isActive, schedule.type == .expense,
                  let priorDay = calendar.date(byAdding: .day, value: -1, to: schedule.nextDate) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: priorDay)
            components.hour = 9; components.minute = 0
            guard let fireDate = calendar.date(from: components), fireDate > now else { return nil }
            return BillReminderPlan(
                identifier: identifierPrefix + schedule.id.uuidString,
                title: AppLanguage.localized("Upcoming Bill"),
                body: String(format: AppLanguage.localized("%@ is due tomorrow."), schedule.name),
                fireDate: fireDate
            )
        }
    }
}

enum BillReminderService {
    static let enabledKey = "billRemindersEnabled"

    static func enableAndSchedule(schedulesJSON: String) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { return false }
        await schedule(schedulesJSON: schedulesJSON)
        return true
    }

    static func schedule(schedulesJSON: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let oldIdentifiers = pending.map(\.identifier).filter { $0.hasPrefix(BillReminderPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIdentifiers)

        for plan in BillReminderPlanner.plans(for: RecurringTransactionStore.decode(schedulesJSON)) {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let request = UNNotificationRequest(identifier: plan.identifier, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }

    static func disable() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(BillReminderPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
