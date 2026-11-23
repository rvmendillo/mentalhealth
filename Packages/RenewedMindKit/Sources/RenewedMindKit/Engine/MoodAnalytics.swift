import Foundation

public enum MoodTrend: String, Sendable {
    case improving, steady, declining, notEnoughData

    public var title: String {
        switch self {
        case .improving: return "Improving"
        case .steady: return "Steady"
        case .declining: return "Dipping"
        case .notEnoughData: return "Keep checking in"
        }
    }
}

public struct DailyMood: Equatable, Sendable, Identifiable {
    public let day: Date
    public let average: Double
    public var id: Date { day }
}

public enum MoodAnalytics {
    /// Exponentially weighted moving average of mood (oldest → newest). `alpha` weights recent check-ins.
    public static func ewma(_ checkIns: [CheckIn], alpha: Double = 0.3) -> Double? {
        let sorted = checkIns.sorted { $0.date < $1.date }
        guard var value = sorted.first.map({ Double($0.mood) }) else { return nil }
        for checkIn in sorted.dropFirst() {
            value = alpha * Double(checkIn.mood) + (1 - alpha) * value
        }
        return value
    }

    /// Average mood per calendar day for the last `days` days (only days with check-ins).
    public static func dailyAverages(_ checkIns: [CheckIn], days: Int, now: Date = Date(),
                                     calendar: Calendar = .current) -> [DailyMood] {
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return [] }
        var buckets: [Date: [Int]] = [:]
        for checkIn in checkIns {
            let day = calendar.startOfDay(for: checkIn.date)
            guard day >= windowStart, day <= todayStart else { continue }
            buckets[day, default: []].append(checkIn.mood)
        }
        return buckets.keys.sorted().map { day in
            let moods = buckets[day]!
            return DailyMood(day: day, average: Double(moods.reduce(0, +)) / Double(moods.count))
        }
    }

    /// Compares the last 7 days with the 7 days before.
    public static func trend(_ checkIns: [CheckIn], now: Date = Date(), calendar: Calendar = .current) -> MoodTrend {
        let todayStart = calendar.startOfDay(for: now)
        guard let recentStart = calendar.date(byAdding: .day, value: -6, to: todayStart),
              let priorStart = calendar.date(byAdding: .day, value: -13, to: todayStart) else { return .notEnoughData }
        let recent = checkIns.filter { $0.date >= recentStart && $0.date <= now }.map(\.mood)
        let prior = checkIns.filter { $0.date >= priorStart && $0.date < recentStart }.map(\.mood)
        guard recent.count >= 2, prior.count >= 2 else { return .notEnoughData }
        let recentMean = Double(recent.reduce(0, +)) / Double(recent.count)
        let priorMean = Double(prior.reduce(0, +)) / Double(prior.count)
        let delta = recentMean - priorMean
        if delta >= 0.5 { return .improving }
        if delta <= -0.5 { return .declining }
        return .steady
    }

    /// True when low mood has persisted: at least 4 low check-ins (mood ≤ 2) making up at least half
    /// of the check-ins in the last 14 days. Used to gently suggest reaching out for support.
    public static func sustainedLowMood(_ checkIns: [CheckIn], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let start = calendar.date(byAdding: .day, value: -14, to: now) else { return false }
        let window = checkIns.filter { $0.date > start && $0.date <= now }
        let low = window.filter { $0.mood <= 2 }.count
        return low >= 4 && Double(low) >= Double(window.count) * 0.5
    }

    /// Consecutive days, ending today (or yesterday, so the streak isn't lost before today's activity), with any activity.
    public static func streak(activityDates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(activityDates.filter { $0 <= now }.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        var cursor: Date
        if days.contains(today) {
            cursor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
