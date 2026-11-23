import Foundation
import SwiftUI
import RenewedMindKit

/// The app's single source of truth. Owns the stored data and coordinates the engines.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var data: AppData
    @Published var alertMessage: String?
    @Published private(set) var hasClaudeKey: Bool
    @Published var selectedTab: AppTab = .today

    let library: ContentLibrary
    let isUITesting: Bool
    private let store: DataStore
    private let keychain: KeychainStore
    private let coordinator: ReframeCoordinator
    private let recommender: RecommendationEngine

    init(store: DataStore, library: ContentLibrary = .shared, keychain: KeychainStore = KeychainStore(),
         isUITesting: Bool = false) {
        self.store = store
        self.library = library
        self.keychain = keychain
        self.isUITesting = isUITesting
        self.coordinator = ReframeCoordinator(library: library)
        self.recommender = RecommendationEngine(library: library)
        let (loaded, outcome) = store.load()
        self.data = loaded
        self.hasClaudeKey = isUITesting ? false : (keychain.load() != nil)
        if case .recoveredFromCorruption = outcome {
            alertMessage = "Your saved data couldn't be read, so a fresh journal was started. The unreadable file was kept on this device."
        }
    }

    // MARK: Persistence

    func update(_ mutate: (inout AppData) -> Void) {
        mutate(&data)
        persist()
    }

    private func persist() {
        do {
            try store.save(data)
        } catch {
            alertMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    // MARK: Profile & onboarding

    var displayName: String {
        let name = data.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "friend" : name
    }

    func completeOnboarding(name: String) {
        update {
            $0.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.profile.hasCompletedOnboarding = true
        }
    }

    func setName(_ name: String) {
        update { $0.profile.name = name }
    }

    // MARK: Affirmations

    var dailyAffirmation: Affirmation { library.dailyAffirmation(for: Date()) }

    func toggleFavorite(_ id: String) {
        update { $0.toggleFavorite(id) }
        Haptics.tap()
    }

    func isFavorite(_ id: String) -> Bool { data.isFavorite(id) }

    var favoriteAffirmations: [Affirmation] { data.favorites.compactMap { library.affirmation(id: $0) } }

    // MARK: Check-ins

    var todaysCheckIn: CheckIn? {
        data.checkIns.filter { Calendar.current.isDateInToday($0.date) }.max { $0.date < $1.date }
    }

    func addCheckIn(mood: Int, factors: [CheckInFactor], note: String) {
        update { $0.checkIns.append(CheckIn(mood: mood, factors: factors, note: note.trimmingCharacters(in: .whitespacesAndNewlines))) }
        Haptics.success()
    }

    var needsGentleCheckIn: Bool { MoodAnalytics.sustainedLowMood(data.checkIns) }

    // MARK: Reframing

    var aiChoice: AIRouter.Choice {
        AIRouter.choose(mode: data.settings.aiMode, model: data.settings.claudeModel,
                        apiKey: isUITesting ? nil : keychain.load())
    }

    func reframe(_ thought: String) async -> ReframeResult {
        let choice = aiChoice
        var result = await coordinator.reframe(thought, ai: choice.reframer)
        if result.notice == nil, let note = choice.note {
            result.notice = note
        }
        return result
    }

    @discardableResult
    func saveReframe(thought: String, emotion: String, intensityBefore: Int?, intensityAfter: Int?,
                     result: ReframeResult, ownBalancedThought: String) -> ReframeEntry {
        let entry = ReframeEntry(thought: thought, emotion: emotion, intensityBefore: intensityBefore,
                                 intensityAfter: intensityAfter, result: result,
                                 ownBalancedThought: ownBalancedThought.trimmingCharacters(in: .whitespacesAndNewlines))
        update { $0.reframes.append(entry) }
        Haptics.success()
        return entry
    }

    func deleteReframes(ids: Set<UUID>) {
        update { $0.reframes.removeAll { ids.contains($0.id) } }
    }

    var recentReframes: [ReframeEntry] { data.reframes.sorted { $0.date > $1.date } }

    // MARK: Practices

    /// Recommendations are re-sampled when the day or the person's activity changes, and stay stable
    /// between screen refreshes in the meantime.
    func recommendations(count: Int = 3) -> [Recommendation] {
        let context = RecommendationContext.from(data: data, library: library)
        let day = ContentLibrary.dayNumber(for: Date(), calendar: .current)
        let ratings = data.practiceStats.values.reduce(0.0) { $0 + $1.ratings }
        let key = "\(day)-\(data.checkIns.count)-\(data.sessions.count)-\(data.reframes.count)-\(ratings)"
        var rng = SplitMix64(seed: isUITesting ? 7 : TextTools.stableHash(key))
        return recommender.recommend(context: context, count: count, using: &rng)
    }

    @discardableResult
    func recordSession(practiceID: String, seconds: Int) -> UUID {
        let session = PracticeSession(practiceID: practiceID, seconds: seconds)
        update { $0.record(session: session) }
        return session.id
    }

    func setFeedback(_ feedback: PracticeFeedback, sessionID: UUID) {
        update { $0.setFeedback(feedback, forSession: sessionID) }
    }

    func saveJournal(practiceID: String, responses: [String]) {
        let entry = JournalEntry(practiceID: practiceID, responses: responses.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        guard !entry.isEmpty else { return }
        update { $0.journal.append(entry) }
    }

    func journalEntries(for practiceID: String) -> [JournalEntry] {
        data.journal.filter { $0.practiceID == practiceID }.sorted { $0.date > $1.date }
    }

    /// Practices the person has rated, best first.
    var practicesThatHelp: [HelpfulPractice] {
        var items: [HelpfulPractice] = []
        for (id, stats) in data.practiceStats where stats.ratings > 0 {
            guard let practice = library.practice(id: id) else { continue }
            let score = RecommendationEngine.posteriorMean(level: practice.evidenceLevel, stats: stats)
            items.append(HelpfulPractice(practice: practice, score: score, ratings: stats.ratings))
        }
        return items.sorted { $0.score == $1.score ? $0.practice.title < $1.practice.title : $0.score > $1.score }
    }

    // MARK: Well-being

    func saveWHO5(answers: [Int]) throws -> WHO5Result {
        let result = try WHO5Result(answers: answers)
        update { $0.wellbeing.append(result) }
        return result
    }

    var latestWHO5: WHO5Result? { data.wellbeing.max { $0.date < $1.date } }

    var flourish: FlourishSnapshot { FlourishCalculator.snapshot(data: data, library: library) }

    var streak: Int { MoodAnalytics.streak(activityDates: data.activityDates) }

    // MARK: Settings

    func setAIMode(_ mode: AIMode) { update { $0.settings.aiMode = mode } }

    func setClaudeModel(_ model: ClaudeModel) { update { $0.settings.claudeModel = model } }

    func saveAPIKey(_ key: String) {
        do {
            try keychain.save(key)
            hasClaudeKey = keychain.load() != nil
        } catch {
            alertMessage = "Couldn't save the key: \(error.localizedDescription)"
        }
    }

    func removeAPIKey() {
        keychain.delete()
        hasClaudeKey = false
    }

    func setReminder(enabled: Bool, hour: Int, minute: Int) async {
        if enabled {
            let granted = await NotificationService.requestAuthorization()
            guard granted else {
                update { $0.settings.reminderEnabled = false }
                alertMessage = "Notifications are turned off for Renewed Mind. You can allow them in the Settings app."
                return
            }
        }
        update {
            $0.settings.reminderEnabled = enabled
            $0.settings.reminderHour = hour
            $0.settings.reminderMinute = minute
        }
        await refreshReminders()
    }

    /// Re-plans the next week of reminders (called on launch so each day keeps its own affirmation).
    func refreshReminders() async {
        guard !isUITesting else { return }
        if data.settings.reminderEnabled {
            let plan = ReminderPlanner.plan(from: Date(), hour: data.settings.reminderHour,
                                            minute: data.settings.reminderMinute, calendar: .current, library: library)
            await NotificationService.schedule(plan)
        } else {
            await NotificationService.cancelAll()
        }
    }

    var crisisRegion: CrisisRegion {
        let code = data.settings.regionOverride ?? Locale.current.region?.identifier
        return CrisisDirectory.region(for: code)
    }

    func setRegionOverride(_ code: String?) { update { $0.settings.regionOverride = code } }

    // MARK: Data

    func exportFileURL() -> URL? {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("RenewedMind-export.json")
            try DataStore.exportJSON(data).write(to: url, options: .atomic)
            return url
        } catch {
            alertMessage = "Couldn't export: \(error.localizedDescription)"
            return nil
        }
    }

    func deleteAllData() {
        do {
            try store.deleteAll()
        } catch {
            alertMessage = "Couldn't delete: \(error.localizedDescription)"
        }
        keychain.delete()
        hasClaudeKey = false
        data = AppData()
        selectedTab = .today
        Task { await NotificationService.cancelAll() }
    }
}

struct HelpfulPractice: Identifiable {
    let practice: Practice
    let score: Double
    let ratings: Double
    var id: String { practice.id }
}

enum AppTab: Hashable {
    case today, renew, practices, library, insights
}
