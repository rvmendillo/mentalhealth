import Foundation

public struct PlannedReminder: Equatable, Sendable, Identifiable {
    public let id: String
    public let dateComponents: DateComponents
    public let title: String
    public let body: String
    public let affirmationID: String
}

/// Plans a week of daily affirmation notifications. Each day gets that day's affirmation,
/// so notifications are scheduled individually rather than as one repeating notification.
public enum ReminderPlanner {
    public static let identifierPrefix = "daily-affirmation-"

    public static func plan(from now: Date, days: Int = 7, hour: Int, minute: Int, calendar: Calendar,
                            library: ContentLibrary) -> [PlannedReminder] {
        guard days > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        var reminders: [PlannedReminder] = []
        var offset = 0
        while reminders.count < days, offset < days + 2 {
            defer { offset += 1 }
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { continue }
            let affirmation = library.dailyAffirmation(for: fire, calendar: calendar)
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            components.calendar = nil
            components.timeZone = nil
            let ymd = calendar.dateComponents([.year, .month, .day], from: fire)
            let id = identifierPrefix + String(format: "%04d-%02d-%02d", ymd.year ?? 0, ymd.month ?? 0, ymd.day ?? 0)
            reminders.append(PlannedReminder(
                id: id,
                dateComponents: components,
                title: "Today's affirmation",
                body: "\(affirmation.affirmation) — \(affirmation.reference)",
                affirmationID: affirmation.id))
        }
        return reminders
    }
}
