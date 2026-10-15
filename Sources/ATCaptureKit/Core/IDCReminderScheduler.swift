import Foundation
import UserNotifications

enum IDCReminderScheduler {
    private static let requestIdentifier = "idc.passport.upload.reminder"

    @discardableResult
    static func schedule(at date: Date) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = IDCStrings.Reminder.notificationTitle
        content.body = IDCStrings.Reminder.notificationBody
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}
