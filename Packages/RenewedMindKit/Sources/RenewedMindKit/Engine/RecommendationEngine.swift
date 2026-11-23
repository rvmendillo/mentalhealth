import Foundation

/// Deterministic, seedable random number generator (SplitMix64). Used so recommendations are testable.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Samplers for the Beta distribution (via two Gamma draws; Marsaglia & Tsang, 2000).
public enum Distributions {
    /// Uniform in the open interval (0, 1).
    static func uniform<G: RandomNumberGenerator>(_ rng: inout G) -> Double {
        var u = 0.0
        repeat { u = Double.random(in: 0..<1, using: &rng) } while u <= .ulpOfOne
        return u
    }

    static func standardNormal<G: RandomNumberGenerator>(_ rng: inout G) -> Double {
        // Box–Muller transform.
        let u1 = uniform(&rng)
        let u2 = uniform(&rng)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }

    public static func gamma<G: RandomNumberGenerator>(shape: Double, using rng: inout G) -> Double {
        precondition(shape > 0, "shape must be positive")
        if shape < 1 {
            // Boost: Gamma(a) = Gamma(a + 1) * U^(1/a)
            let u = uniform(&rng)
            return gamma(shape: shape + 1, using: &rng) * pow(u, 1 / shape)
        }
        let d = shape - 1.0 / 3.0
        let c = 1.0 / (9 * d).squareRoot()
        while true {
            var x: Double
            var v: Double
            repeat {
                x = standardNormal(&rng)
                v = 1 + c * x
            } while v <= 0
            v = v * v * v
            let u = uniform(&rng)
            if u < 1 - 0.0331 * x * x * x * x { return d * v }
            if log(u) < 0.5 * x * x + d * (1 - v + log(v)) { return d * v }
        }
    }

    public static func beta<G: RandomNumberGenerator>(alpha: Double, beta: Double, using rng: inout G) -> Double {
        let x = gamma(shape: alpha, using: &rng)
        let y = gamma(shape: beta, using: &rng)
        let sum = x + y
        return sum > 0 ? x / sum : 0.5
    }
}

public struct Recommendation: Equatable, Sendable, Identifiable {
    public let practiceID: String
    public let score: Double
    /// Short, human-readable reasons ("Because you mentioned trouble sleeping").
    public let reasons: [String]
    public var id: String { practiceID }
}

/// The context the recommender uses: what the person is facing and what has helped them before.
public struct RecommendationContext: Sendable {
    public var needs: [WellbeingNeed: Double]
    public var stats: [String: PracticeStats]
    public var recentDimensions: [WellnessDimension: Int]
    public var now: Date
    public var calendar: Calendar

    public init(needs: [WellbeingNeed: Double] = [:], stats: [String: PracticeStats] = [:],
                recentDimensions: [WellnessDimension: Int] = [:], now: Date = Date(), calendar: Calendar = .current) {
        self.needs = needs
        self.stats = stats
        self.recentDimensions = recentDimensions
        self.now = now
        self.calendar = calendar
    }

    /// Builds the context from stored data: today's check-in, recent reframes, and the latest WHO-5.
    public static func from(data: AppData, library: ContentLibrary, now: Date = Date(),
                            calendar: Calendar = .current) -> RecommendationContext {
        var needs: [WellbeingNeed: Double] = [:]
        func add(_ need: WellbeingNeed, _ weight: Double) { needs[need] = max(needs[need] ?? 0, weight) }

        let dayAgo = now.addingTimeInterval(-24 * 3_600)
        let twoDaysAgo = now.addingTimeInterval(-48 * 3_600)
        if let latest = data.checkIns.filter({ $0.date > dayAgo && $0.date <= now }).max(by: { $0.date < $1.date }) {
            for factor in latest.factors {
                if let need = factor.need { add(need, 1.0) }
            }
            if latest.mood <= 2 { add(.lowMood, latest.mood == 1 ? 1.0 : 0.8) }
        }
        for entry in data.reframes where entry.date > twoDaysAgo && entry.date <= now {
            for concern in entry.result.concerns { add(concern.guidance.need, 0.6) }
        }
        if let who5 = data.wellbeing.max(by: { $0.date < $1.date }),
           now.timeIntervalSince(who5.date) < 30 * 86_400, who5.band != .good {
            add(.lowMood, who5.band == .veryLow ? 0.9 : 0.6)
        }

        var dims: [WellnessDimension: Int] = [:]
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        for session in data.sessions where session.date > weekAgo && session.date <= now {
            if let practice = library.practice(id: session.practiceID) {
                dims[practice.dimension, default: 0] += 1
            }
        }
        return RecommendationContext(needs: needs, stats: data.practiceStats, recentDimensions: dims, now: now,
                                     calendar: calendar)
    }
}

/// Personalized practice recommendations.
///
/// The score blends four research-informed ideas:
/// 1. **Fit to current needs** — practices targeting what the person reported today.
/// 2. **Person–activity fit, learned over time** — Thompson sampling over each practice's
///    "did it help?" ratings (Thompson, 1933; Russo et al., 2018), with an evidence-based prior.
///    Positive activities work best when they fit the person (Lyubomirsky & Layous, 2013).
/// 3. **Variety** — a recency penalty to reduce hedonic adaptation (Sheldon & Lyubomirsky, 2012).
/// 4. **Balance and timing** — a nudge toward neglected wellness dimensions and time-of-day fit.
public struct RecommendationEngine: Sendable {
    public let library: ContentLibrary

    public init(library: ContentLibrary) {
        self.library = library
    }

    public static func prior(for level: EvidenceLevel) -> (alpha: Double, beta: Double) {
        switch level {
        case .strong: return (3, 1)
        case .moderate: return (2, 1)
        case .emerging: return (1.5, 1)
        }
    }

    /// Posterior mean of "this practice helps", combining the evidence prior and personal ratings.
    public static func posteriorMean(level: EvidenceLevel, stats: PracticeStats?) -> Double {
        let p = prior(for: level)
        let a = p.alpha + (stats?.successes ?? 0)
        let b = p.beta + (stats?.failures ?? 0)
        return a / (a + b)
    }

    func needScore(_ practice: Practice, needs: [WellbeingNeed: Double]) -> (score: Double, topNeed: WellbeingNeed?) {
        var total = 0.0
        var top: (WellbeingNeed, Double)?
        for need in practice.needs {
            guard let weight = needs[need], weight > 0 else { continue }
            total += weight
            if top == nil || weight > top!.1 { top = (need, weight) }
        }
        return (min(1.0, total / 1.5), top?.0)
    }

    func recencyPenalty(_ stats: PracticeStats?, now: Date) -> Double {
        guard let last = stats?.lastCompleted else { return 0 }
        let hours = now.timeIntervalSince(last) / 3_600
        if hours < 0 { return 0 }
        if hours < 12 { return 0.6 }
        if hours < 36 { return 0.3 }
        if hours < 72 { return 0.1 }
        return 0
    }

    func timeFit(_ practice: Practice, hour: Int) -> Double {
        let evening = hour >= 19 || hour < 3
        let lateNight = hour >= 21 || hour < 4
        let daytime = (7..<19).contains(hour)
        let morning = (5..<11).contains(hour)
        switch practice.id {
        case "sleep-wind-down":
            return lateNight ? 0.35 : (evening ? 0.2 : -0.25)
        case "three-good-things", "daily-examen":
            return evening ? 0.15 : 0
        case "move-your-body", "consider-the-lilies", "savoring-walk":
            return daytime ? 0.1 : -0.2
        case "best-possible-self", "use-your-gifts":
            return morning ? 0.1 : 0
        case "sabbath-pause":
            return lateNight ? -0.2 : 0
        default:
            return 0
        }
    }

    func balanceBonus(_ practice: Practice, recent: [WellnessDimension: Int]) -> Double {
        let total = recent.values.reduce(0, +)
        guard total > 0 else { return 0 }
        let share = Double(recent[practice.dimension] ?? 0) / Double(total)
        return share == 0 ? 0.08 : (share < 0.15 ? 0.04 : 0)
    }

    /// Ranks practices for the person. Deterministic for a given generator state.
    public func recommend<G: RandomNumberGenerator>(context: RecommendationContext, count: Int = 3,
                                                    using rng: inout G) -> [Recommendation] {
        let hour = context.calendar.component(.hour, from: context.now)
        var results: [Recommendation] = []
        for practice in library.practices {
            let stats = context.stats[practice.id]
            let prior = Self.prior(for: practice.evidenceLevel)
            let sample = Distributions.beta(alpha: prior.alpha + (stats?.successes ?? 0),
                                            beta: prior.beta + (stats?.failures ?? 0), using: &rng)
            let need = needScore(practice, needs: context.needs)
            let recency = recencyPenalty(stats, now: context.now)
            let timing = timeFit(practice, hour: hour)
            let balance = balanceBonus(practice, recent: context.recentDimensions)
            let score = 0.5 * need.score + 0.35 * sample + timing + balance - recency

            var reasons: [String] = []
            if let topNeed = need.topNeed { reasons.append("Because you mentioned \(topNeed.phrase)") }
            if let stats, stats.ratings >= 2, Self.posteriorMean(level: practice.evidenceLevel, stats: stats) >= 0.7 {
                reasons.append("This has helped you before")
            }
            if (stats?.completions ?? 0) == 0 { reasons.append("Something new to try") }
            if timing > 0.05 { reasons.append("A good fit for this time of day") }
            if balance > 0 { reasons.append("Adds balance: \(practice.dimension.title.lowercased())") }
            if reasons.isEmpty { reasons.append(practice.evidenceLevel.title) }
            results.append(Recommendation(practiceID: practice.id, score: score, reasons: reasons))
        }
        results.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.practiceID < rhs.practiceID
        }
        return Array(results.prefix(max(0, count)))
    }

    /// Convenience using the system random generator.
    public func recommend(context: RecommendationContext, count: Int = 3) -> [Recommendation] {
        var rng = SystemRandomNumberGenerator()
        return recommend(context: context, count: count, using: &rng)
    }
}
