import Foundation

/// The WHO-5 Well-Being Index (Psychiatric Research Unit, WHO Collaborating Centre in Mental Health).
/// Five items about the last two weeks, each scored 0–5. Raw score 0–25 is multiplied by 4 to give 0–100.
/// See Topp et al. (2015), Psychotherapy and Psychosomatics, 84(3), 167–176.
public enum WHO5 {
    public static let prompt = "Over the last two weeks…"

    public static let items: [String] = [
        "I have felt cheerful and in good spirits",
        "I have felt calm and relaxed",
        "I have felt active and vigorous",
        "I woke up feeling fresh and rested",
        "My daily life has been filled with things that interest me",
    ]

    public struct Option: Hashable, Sendable, Identifiable {
        public let label: String
        public let value: Int
        public var id: Int { value }
    }

    /// Answer options from highest (5) to lowest (0).
    public static let options: [Option] = [
        Option(label: "All of the time", value: 5),
        Option(label: "Most of the time", value: 4),
        Option(label: "More than half of the time", value: 3),
        Option(label: "Less than half of the time", value: 2),
        Option(label: "Some of the time", value: 1),
        Option(label: "At no time", value: 0),
    ]

    public enum ScoreError: Error, Equatable {
        case wrongNumberOfAnswers(Int)
        case answerOutOfRange(Int)
    }

    /// Returns the percentage score (0–100).
    public static func score(_ answers: [Int]) throws -> Int {
        guard answers.count == items.count else { throw ScoreError.wrongNumberOfAnswers(answers.count) }
        for answer in answers where !(0...5).contains(answer) {
            throw ScoreError.answerOutOfRange(answer)
        }
        return answers.reduce(0, +) * 4
    }

    public static let attribution = "WHO-5 Well-Being Index © Psychiatric Research Unit, Mental Health Centre North Zealand. Used for self-reflection only; it is not a diagnosis."
}

public enum WHO5Band: String, Codable, Sendable {
    /// Above 50.
    case good
    /// 29–50: low well-being; screening for depression is recommended.
    case low
    /// 0–28: very low well-being; often associated with depression.
    case veryLow

    public static func band(forPercent score: Int) -> WHO5Band {
        if score <= 28 { return .veryLow }
        if score <= 50 { return .low }
        return .good
    }

    public var title: String {
        switch self {
        case .good: return "Good well-being"
        case .low: return "Low well-being"
        case .veryLow: return "Very low well-being"
        }
    }

    public var guidance: String {
        switch self {
        case .good:
            return "Your answers suggest good well-being. Keep investing in the habits and relationships that help you flourish."
        case .low:
            return "Your answers suggest your well-being is low right now. That's worth taking seriously: consider talking with your doctor, a counselor, or your pastor, and lean on people you trust."
        case .veryLow:
            return "Your answers suggest very low well-being, which is often linked with depression. Please consider reaching out to a doctor or mental health professional soon. You deserve support, and help works."
        }
    }
}

public struct WHO5Result: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var answers: [Int]

    public init(id: UUID = UUID(), date: Date = Date(), answers: [Int]) throws {
        _ = try WHO5.score(answers)
        self.id = id
        self.date = date
        self.answers = answers
    }

    /// 0–100. Returns 0 for malformed stored data rather than crashing.
    public var percentScore: Int { (try? WHO5.score(answers)) ?? 0 }
    public var rawScore: Int { percentScore / 4 }
    public var band: WHO5Band { WHO5Band.band(forPercent: percentScore) }
}

/// A weekly picture of holistic flourishing across six dimensions (0–100 each).
/// This is a reflection aid built from the person's own activity, not a clinical measure.
public struct FlourishSnapshot: Equatable, Sendable {
    public let scores: [WellnessDimension: Int]
    public let overall: Int
    public let averageMood: Double?

    public func score(_ dimension: WellnessDimension) -> Int { scores[dimension] ?? 0 }

    /// The dimension that could use the most care this week.
    public var focusDimension: WellnessDimension? {
        WellnessDimension.allCases.min { score($0) < score($1) }
    }
}

public enum FlourishCalculator {
    /// Points needed in a week for a full score in a dimension.
    public static let weeklyTarget = 3.0

    public static func snapshot(data: AppData, library: ContentLibrary, now: Date = Date(),
                                calendar: Calendar = .current) -> FlourishSnapshot {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-7 * 86_400)
        func inWindow(_ date: Date) -> Bool { date > weekAgo && date <= now }

        var points: [WellnessDimension: Double] = [:]
        for session in data.sessions where inWindow(session.date) {
            if let practice = library.practice(id: session.practiceID) {
                points[practice.dimension, default: 0] += 1
            }
        }
        let recentCheckIns = data.checkIns.filter { inWindow($0.date) }
        for checkIn in recentCheckIns {
            for factor in checkIn.factors {
                if let dimension = factor.strengthDimension {
                    points[dimension, default: 0] += 0.5
                }
            }
        }
        let recentReframes = data.reframes.filter { inWindow($0.date) }
        points[.mental, default: 0] += Double(recentReframes.count)
        let journalCount = data.journal.filter { inWindow($0.date) && !$0.isEmpty }.count
        points[.emotional, default: 0] += Double(journalCount) * 0.5

        var scores: [WellnessDimension: Int] = [:]
        for dimension in WellnessDimension.allCases {
            let activity = min(1.0, (points[dimension] ?? 0) / weeklyTarget)
            scores[dimension] = Int((activity * 100).rounded())
        }

        var averageMood: Double?
        if !recentCheckIns.isEmpty {
            let mean = Double(recentCheckIns.map(\.mood).reduce(0, +)) / Double(recentCheckIns.count)
            averageMood = mean
            // Emotional score blends mood (60%) with emotional practices (40%).
            let moodScore = (mean - 1) / 4 * 100
            let activityScore = Double(scores[.emotional] ?? 0)
            scores[.emotional] = Int((0.6 * moodScore + 0.4 * activityScore).rounded())
        }

        let overall = Int((Double(scores.values.reduce(0, +)) / Double(WellnessDimension.allCases.count)).rounded())
        return FlourishSnapshot(scores: scores, overall: overall, averageMood: averageMood)
    }
}
