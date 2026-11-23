import XCTest
@testable import RenewedMindKit

final class RecommendationTests: XCTestCase {
    let library = TestSupport.library
    lazy var engine = RecommendationEngine(library: library)
    let cal = TestSupport.calendar()

    private func context(needs: [WellbeingNeed: Double] = [:], hour: Int = 14,
                         stats: [String: PracticeStats] = [:]) -> RecommendationContext {
        RecommendationContext(needs: needs, stats: stats, now: TestSupport.date(2026, 11, 20, hour, calendar: cal),
                              calendar: cal)
    }

    private func topIDs(_ ctx: RecommendationContext, seed: UInt64, count: Int = 3) -> [String] {
        var rng = SplitMix64(seed: seed)
        return engine.recommend(context: ctx, count: count, using: &rng).map(\.practiceID)
    }

    func testSleepNeedAtNightSurfacesSleepWindDown() {
        let ctx = context(needs: [.sleep: 1.0], hour: 22)
        let hits = (0..<100).filter { topIDs(ctx, seed: UInt64($0)).contains("sleep-wind-down") }.count
        XCTAssertGreaterThanOrEqual(hits, 95)
    }

    func testAnxietySurfacesCalmingPractices() {
        let calming: Set<String> = ["breath-prayer", "cyclic-sighing", "grounding-54321", "move-your-body",
                                    "self-compassion-break", "scripture-meditation", "consider-the-lilies"]
        let ctx = context(needs: [.anxiety: 1.0])
        for seed in 0..<100 {
            let ids = topIDs(ctx, seed: UInt64(seed))
            XCTAssertTrue(ids.contains { calming.contains($0) }, "\(ids)")
        }
    }

    func testRecencyPenaltyIsApplied() {
        let now = TestSupport.date(2026, 11, 20, 14, calendar: cal)
        let recent = PracticeStats(completions: 1, lastCompleted: now.addingTimeInterval(-3_600))
        var rng1 = SplitMix64(seed: 42)
        var rng2 = SplitMix64(seed: 42)
        let base = engine.recommend(context: context(), count: 20, using: &rng1)
        let penalized = engine.recommend(context: context(stats: ["three-good-things": recent]), count: 20, using: &rng2)
        let a = base.first { $0.practiceID == "three-good-things" }!.score
        let b = penalized.first { $0.practiceID == "three-good-things" }!.score
        XCTAssertEqual(a - b, 0.6, accuracy: 1e-9)
    }

    func testLearnsFromHelpfulRatings() {
        let liked = PracticeStats(successes: 12, failures: 0, completions: 12,
                                  lastCompleted: TestSupport.date(2026, 11, 1, calendar: cal))
        let disliked = PracticeStats(successes: 0, failures: 12, completions: 12,
                                     lastCompleted: TestSupport.date(2026, 11, 1, calendar: cal))
        let likedCtx = context(stats: ["savoring-walk": liked])
        let dislikedCtx = context(stats: ["savoring-walk": disliked])
        let likedHits = (0..<200).filter { topIDs(likedCtx, seed: UInt64($0)).contains("savoring-walk") }.count
        let dislikedHits = (0..<200).filter { topIDs(dislikedCtx, seed: UInt64($0)).contains("savoring-walk") }.count
        XCTAssertGreaterThan(likedHits, dislikedHits + 50)
        XCTAssertGreaterThan(RecommendationEngine.posteriorMean(level: .moderate, stats: liked), 0.9)
        XCTAssertLessThan(RecommendationEngine.posteriorMean(level: .moderate, stats: disliked), 0.25)
    }

    func testRecommendationsAreUniqueWithReasons() {
        var rng = SplitMix64(seed: 7)
        let recs = engine.recommend(context: context(needs: [.loneliness: 1]), count: 5, using: &rng)
        XCTAssertEqual(recs.count, 5)
        XCTAssertEqual(Set(recs.map(\.practiceID)).count, 5)
        for r in recs {
            XCTAssertFalse(r.reasons.isEmpty)
            XCTAssertNotNil(library.practice(id: r.practiceID))
        }
        XCTAssertTrue(recs[0].reasons.contains("Because you mentioned feeling lonely") || recs.contains { $0.practiceID == "reach-out" })
        XCTAssertEqual(engine.recommend(context: context(), count: 0).count, 0)
    }

    func testDeterministicWithSeed() {
        XCTAssertEqual(topIDs(context(needs: [.stress: 1]), seed: 99), topIDs(context(needs: [.stress: 1]), seed: 99))
    }

    func testContextFromData() throws {
        let now = TestSupport.date(2026, 11, 20, 9, calendar: cal)
        var data = AppData()
        data.checkIns = [CheckIn(date: now.addingTimeInterval(-3_600), mood: 2, factors: [.poorSleep, .lonely, .grateful])]
        data.wellbeing = [try WHO5Result(date: now.addingTimeInterval(-86_400), answers: [1, 1, 1, 1, 1])]
        let ctx = RecommendationContext.from(data: data, library: library, now: now, calendar: cal)
        XCTAssertEqual(ctx.needs[.sleep], 1.0)
        XCTAssertEqual(ctx.needs[.loneliness], 1.0)
        XCTAssertEqual(ctx.needs[.lowMood] ?? 0, 0.9, accuracy: 1e-9)
        XCTAssertNil(ctx.needs[.anger])

        // Old check-ins are ignored.
        data.checkIns = [CheckIn(date: now.addingTimeInterval(-3 * 86_400), mood: 1, factors: [.anxious])]
        data.wellbeing = []
        XCTAssertTrue(RecommendationContext.from(data: data, library: library, now: now, calendar: cal).needs.isEmpty)
    }

    func testBetaSamplerMeans() {
        var rng = SplitMix64(seed: 2024)
        for (a, b) in [(3.0, 1.0), (1.5, 1.0), (2.0, 5.0), (0.5, 0.5)] {
            let n = 20_000
            var sum = 0.0
            for _ in 0..<n {
                let x = Distributions.beta(alpha: a, beta: b, using: &rng)
                XCTAssertTrue((0...1).contains(x))
                sum += x
            }
            XCTAssertEqual(sum / Double(n), a / (a + b), accuracy: 0.01, "Beta(\(a), \(b))")
        }
    }

    func testGammaSamplerMean() {
        var rng = SplitMix64(seed: 1)
        for shape in [0.5, 1.0, 2.5, 9.0] {
            let n = 20_000
            let mean = (0..<n).reduce(0.0) { acc, _ in acc + Distributions.gamma(shape: shape, using: &rng) } / Double(n)
            XCTAssertEqual(mean, shape, accuracy: shape * 0.04 + 0.01, "Gamma(\(shape))")
        }
    }

    func testSplitMixIsDeterministic() {
        var a = SplitMix64(seed: 5)
        var b = SplitMix64(seed: 5)
        for _ in 0..<10 { XCTAssertEqual(a.next(), b.next()) }
    }

    func testPracticeStatsFeedback() {
        var data = AppData()
        let session = PracticeSession(practiceID: "breath-prayer", seconds: 180)
        data.record(session: session)
        data.setFeedback(.helped, forSession: session.id)
        XCTAssertEqual(data.practiceStats["breath-prayer"]?.successes, 1)
        // Changing the rating replaces, rather than adds to, the earlier one.
        data.setFeedback(.notReally, forSession: session.id)
        XCTAssertEqual(data.practiceStats["breath-prayer"]?.successes, 0)
        XCTAssertEqual(data.practiceStats["breath-prayer"]?.failures, 1)
        XCTAssertEqual(data.practiceStats["breath-prayer"]?.completions, 1)
        XCTAssertNotNil(data.practiceStats["breath-prayer"]?.lastCompleted)
    }
}
