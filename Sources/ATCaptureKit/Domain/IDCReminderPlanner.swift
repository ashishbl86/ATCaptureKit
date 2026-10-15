import Foundation

enum IDCReminderPlanner {
    static let eveningHour = 20
    static let morningHour = 9
    static let minimumLeadInterval: TimeInterval = 30 * 60
    static let lateEveningFallbackInterval: TimeInterval = 2 * 60 * 60
    static let minimumScheduleLead: TimeInterval = 60

    static func tonight(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let evening = calendar.date(bySettingHour: eveningHour, minute: 0, second: 0, of: now) ?? now
        return evening > now.addingTimeInterval(minimumLeadInterval)
            ? evening
            : now.addingTimeInterval(lateEveningFallbackInterval)
    }

    static func tomorrowMorning(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: morningHour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    static func customDate(
        dayOffset: Int,
        hour12: Int,
        minute: Int,
        isPM: Bool,
        reference: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: reference) ?? reference
        let hour24 = isPM ? (hour12 == 12 ? 12 : hour12 + 12) : (hour12 == 12 ? 0 : hour12)
        let composed = calendar.date(bySettingHour: hour24, minute: minute, second: 0, of: day) ?? day
        return max(composed, now.addingTimeInterval(minimumScheduleLead))
    }
}
