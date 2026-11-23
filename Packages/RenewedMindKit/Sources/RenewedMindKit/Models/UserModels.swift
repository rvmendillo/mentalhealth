import Foundation

/// Things a person can tag on a mood check-in.
public enum CheckInFactor: String, Codable, CaseIterable, Sendable, Identifiable {
    // Challenges
    case poorSleep, stressed, anxious, lonely, lowEnergy, conflict, grieving, overwhelmed, spirituallyDry, selfCritical
    // Strengths
    case rested, connected, grateful, active, prayed, outdoors

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .poorSleep: return "Poor sleep"
        case .stressed: return "Stressed"
        case .anxious: return "Anxious"
        case .lonely: return "Lonely"
        case .lowEnergy: return "Low energy"
        case .conflict: return "Conflict"
        case .grieving: return "Grieving"
        case .overwhelmed: return "Overwhelmed"
        case .spirituallyDry: return "Far from God"
        case .selfCritical: return "Hard on myself"
        case .rested: return "Rested"
        case .connected: return "Connected"
        case .grateful: return "Grateful"
        case .active: return "Active"
        case .prayed: return "Prayed"
        case .outdoors: return "Outdoors"
        }
    }

    public var isChallenge: Bool { need != nil }

    /// The need this factor signals, if it is a challenge.
    public var need: WellbeingNeed? {
        switch self {
        case .poorSleep: return .sleep
        case .stressed: return .stress
        case .anxious: return .anxiety
        case .lonely: return .loneliness
        case .lowEnergy: return .lowEnergy
        case .conflict: return .anger
        case .grieving: return .grief
        case .overwhelmed: return .overwhelm
        case .spirituallyDry: return .spiritualDryness
        case .selfCritical: return .selfCriticism
        case .rested, .connected, .grateful, .active, .prayed, .outdoors: return nil
        }
    }

    /// Wellness dimension a positive factor contributes to.
    public var strengthDimension: WellnessDimension? {
        switch self {
        case .rested, .active, .outdoors: return .physical
        case .connected: return .social
        case .grateful: return .emotional
        case .prayed: return .spiritual
        default: return nil
        }
    }

    public static var challenges: [CheckInFactor] { allCases.filter { $0.isChallenge } }
    public static var strengths: [CheckInFactor] { allCases.filter { !$0.isChallenge } }
}

public struct CheckIn: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    /// 1 (very low) … 5 (very good)
    public var mood: Int
    public var factors: [CheckInFactor]
    public var note: String

    public init(id: UUID = UUID(), date: Date = Date(), mood: Int, factors: [CheckInFactor] = [], note: String = "") {
        self.id = id
        self.date = date
        self.mood = min(max(mood, 1), 5)
        self.factors = factors
        self.note = note
    }

    public static let moodLabels = ["Very low", "Low", "Okay", "Good", "Very good"]
    public static let moodEmoji = ["😞", "🙁", "😐", "🙂", "😊"]

    public var moodLabel: String { Self.moodLabels[mood - 1] }
    public var moodEmoji: String { Self.moodEmoji[mood - 1] }
}

/// A saved reframe of a negative thought.
public struct ReframeEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var thought: String
    public var emotion: String
    /// How strongly the person believed / felt the thought before reframing (0–100).
    public var intensityBefore: Int?
    /// After reframing (0–100).
    public var intensityAfter: Int?
    public var result: ReframeResult
    /// The person's own balanced thought, if they rewrote it.
    public var ownBalancedThought: String

    public init(id: UUID = UUID(), date: Date = Date(), thought: String, emotion: String = "",
                intensityBefore: Int? = nil, intensityAfter: Int? = nil, result: ReframeResult,
                ownBalancedThought: String = "") {
        self.id = id
        self.date = date
        self.thought = thought
        self.emotion = emotion
        self.intensityBefore = intensityBefore.map { min(max($0, 0), 100) }
        self.intensityAfter = intensityAfter.map { min(max($0, 0), 100) }
        self.result = result
        self.ownBalancedThought = ownBalancedThought
    }

    /// Positive values mean the distressing feeling decreased.
    public var intensityChange: Int? {
        guard let before = intensityBefore, let after = intensityAfter else { return nil }
        return before - after
    }
}

/// A journal entry written during a practice (gratitude, lament, best possible self…).
public struct JournalEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var practiceID: String
    /// One response per prompt.
    public var responses: [String]

    public init(id: UUID = UUID(), date: Date = Date(), practiceID: String, responses: [String]) {
        self.id = id
        self.date = date
        self.practiceID = practiceID
        self.responses = responses
    }

    public var isEmpty: Bool {
        responses.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

public enum PracticeFeedback: String, Codable, CaseIterable, Sendable {
    case helped, somewhat, notReally

    public var title: String {
        switch self {
        case .helped: return "It helped"
        case .somewhat: return "A little"
        case .notReally: return "Not really"
        }
    }
}

public struct PracticeSession: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var practiceID: String
    public var seconds: Int
    public var feedback: PracticeFeedback?

    public init(id: UUID = UUID(), date: Date = Date(), practiceID: String, seconds: Int = 0,
                feedback: PracticeFeedback? = nil) {
        self.id = id
        self.date = date
        self.practiceID = practiceID
        self.seconds = max(0, seconds)
        self.feedback = feedback
    }
}

/// Beta-distribution counts used by the Thompson-sampling recommender.
public struct PracticeStats: Codable, Hashable, Sendable {
    public var successes: Double
    public var failures: Double
    public var completions: Int
    public var lastCompleted: Date?

    public init(successes: Double = 0, failures: Double = 0, completions: Int = 0, lastCompleted: Date? = nil) {
        self.successes = successes
        self.failures = failures
        self.completions = completions
        self.lastCompleted = lastCompleted
    }

    public mutating func record(_ feedback: PracticeFeedback) {
        switch feedback {
        case .helped: successes += 1
        case .somewhat: successes += 0.5; failures += 0.5
        case .notReally: failures += 1
        }
    }

    public var ratings: Double { successes + failures }
}

public enum AIMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Best available: Claude when an API key is saved, otherwise Apple's on-device model, otherwise offline.
    case automatic
    case claude
    case onDevice
    case offline

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic (best available)"
        case .claude: return "Claude (Anthropic)"
        case .onDevice: return "Apple Intelligence (on-device)"
        case .offline: return "Offline only"
        }
    }
}

public struct UserSettings: Codable, Hashable, Sendable {
    public var reminderEnabled: Bool
    public var reminderHour: Int
    public var reminderMinute: Int
    public var aiMode: AIMode
    public var claudeModel: ClaudeModel
    public var regionOverride: String?

    public init(reminderEnabled: Bool = false, reminderHour: Int = 8, reminderMinute: Int = 0,
                aiMode: AIMode = .automatic, claudeModel: ClaudeModel = .default, regionOverride: String? = nil) {
        self.reminderEnabled = reminderEnabled
        self.reminderHour = min(max(reminderHour, 0), 23)
        self.reminderMinute = min(max(reminderMinute, 0), 59)
        self.aiMode = aiMode
        self.claudeModel = claudeModel
        self.regionOverride = regionOverride
    }

    private enum CodingKeys: String, CodingKey {
        case reminderEnabled, reminderHour, reminderMinute, aiMode, claudeModel, regionOverride
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            reminderEnabled: try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false,
            reminderHour: try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 8,
            reminderMinute: try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0,
            aiMode: (try? c.decodeIfPresent(AIMode.self, forKey: .aiMode)) ?? .automatic,
            claudeModel: (try? c.decodeIfPresent(ClaudeModel.self, forKey: .claudeModel)) ?? .default,
            regionOverride: try c.decodeIfPresent(String.self, forKey: .regionOverride)
        )
    }
}

public struct Profile: Codable, Hashable, Sendable {
    public var name: String
    public var createdAt: Date
    public var hasCompletedOnboarding: Bool

    public init(name: String = "", createdAt: Date = Date(), hasCompletedOnboarding: Bool = false) {
        self.name = name
        self.createdAt = createdAt
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

/// Everything the app stores. Saved as a single JSON file on the device.
public struct AppData: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var profile: Profile
    public var settings: UserSettings
    public var checkIns: [CheckIn]
    public var reframes: [ReframeEntry]
    public var journal: [JournalEntry]
    public var sessions: [PracticeSession]
    public var wellbeing: [WHO5Result]
    public var favorites: [String]
    public var practiceStats: [String: PracticeStats]

    public init(schemaVersion: Int = AppData.currentSchemaVersion, profile: Profile = Profile(),
                settings: UserSettings = UserSettings(), checkIns: [CheckIn] = [], reframes: [ReframeEntry] = [],
                journal: [JournalEntry] = [], sessions: [PracticeSession] = [], wellbeing: [WHO5Result] = [],
                favorites: [String] = [], practiceStats: [String: PracticeStats] = [:]) {
        self.schemaVersion = schemaVersion
        self.profile = profile
        self.settings = settings
        self.checkIns = checkIns
        self.reframes = reframes
        self.journal = journal
        self.sessions = sessions
        self.wellbeing = wellbeing
        self.favorites = favorites
        self.practiceStats = practiceStats
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, profile, settings, checkIns, reframes, journal, sessions, wellbeing, favorites, practiceStats
    }

    /// Tolerant decoding: missing keys fall back to defaults so older files keep working.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? AppData.currentSchemaVersion
        self.profile = try c.decodeIfPresent(Profile.self, forKey: .profile) ?? Profile()
        self.settings = try c.decodeIfPresent(UserSettings.self, forKey: .settings) ?? UserSettings()
        self.checkIns = try c.decodeIfPresent([CheckIn].self, forKey: .checkIns) ?? []
        self.reframes = try c.decodeIfPresent([ReframeEntry].self, forKey: .reframes) ?? []
        self.journal = try c.decodeIfPresent([JournalEntry].self, forKey: .journal) ?? []
        self.sessions = try c.decodeIfPresent([PracticeSession].self, forKey: .sessions) ?? []
        self.wellbeing = try c.decodeIfPresent([WHO5Result].self, forKey: .wellbeing) ?? []
        self.favorites = try c.decodeIfPresent([String].self, forKey: .favorites) ?? []
        self.practiceStats = try c.decodeIfPresent([String: PracticeStats].self, forKey: .practiceStats) ?? [:]
    }

    // MARK: Mutations used by the app

    public mutating func record(session: PracticeSession) {
        sessions.append(session)
        var stats = practiceStats[session.practiceID] ?? PracticeStats()
        stats.completions += 1
        if let last = stats.lastCompleted {
            stats.lastCompleted = max(last, session.date)
        } else {
            stats.lastCompleted = session.date
        }
        if let feedback = session.feedback { stats.record(feedback) }
        practiceStats[session.practiceID] = stats
    }

    /// Adds feedback to an existing session (feedback is often given after finishing).
    public mutating func setFeedback(_ feedback: PracticeFeedback, forSession id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let previous = sessions[index].feedback
        sessions[index].feedback = feedback
        let practiceID = sessions[index].practiceID
        var stats = practiceStats[practiceID] ?? PracticeStats()
        if let previous {
            // Undo the earlier rating before applying the new one.
            switch previous {
            case .helped: stats.successes -= 1
            case .somewhat: stats.successes -= 0.5; stats.failures -= 0.5
            case .notReally: stats.failures -= 1
            }
            stats.successes = max(0, stats.successes)
            stats.failures = max(0, stats.failures)
        }
        stats.record(feedback)
        practiceStats[practiceID] = stats
    }

    public mutating func toggleFavorite(_ affirmationID: String) {
        if let index = favorites.firstIndex(of: affirmationID) {
            favorites.remove(at: index)
        } else {
            favorites.append(affirmationID)
        }
    }

    public func isFavorite(_ affirmationID: String) -> Bool { favorites.contains(affirmationID) }

    /// Dates on which the person did anything meaningful in the app.
    public var activityDates: [Date] {
        checkIns.map(\.date) + reframes.map(\.date) + journal.map(\.date) + sessions.map(\.date) + wellbeing.map(\.date)
    }
}
