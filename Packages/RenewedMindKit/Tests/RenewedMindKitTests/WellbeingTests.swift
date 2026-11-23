import XCTest
@testable import RenewedMindKit

final class WHO5Tests: XCTestCase {
    func testItemsMatchThePublishedInstrument() {
        XCTAssertEqual(WHO5.items, [
            "I have felt cheerful and in good spirits",
            "I have felt calm and relaxed",
            "I have felt active and vigorous",
            "I woke up feeling fresh and rested",
            "My daily life has been filled with things that interest me",
        ])
        XCTAssertEqual(WHO5.options.map(\.value), [5, 4, 3, 2, 1, 0])
        XCTAssertEqual(WHO5.options.first?.label, "All of the time")
        XCTAssertEqual(WHO5.options.last?.label, "At no time")
    }

    func testScoring() throws {
        XCTAssertEqual(try WHO5.score([5, 5, 5, 5, 5]), 100)
        XCTAssertEqual(try WHO5.score([0, 0, 0, 0, 0]), 0)
        XCTAssertEqual(try WHO5.score([3, 3, 2, 2, 3]), 52)
        XCTAssertThrowsError(try WHO5.score([1, 2, 3])) { error in
            XCTAssertEqual(error as? WHO5.ScoreError, .wrongNumberOfAnswers(3))
        }
        XCTAssertThrowsError(try WHO5.score([1, 2, 3, 4, 6]))
        XCTAssertThrowsError(try WHO5.score([-1, 2, 3, 4, 5]))
    }

    func testBands() {
        XCTAssertEqual(WHO5Band.band(forPercent: 100), .good)
        XCTAssertEqual(WHO5Band.band(forPercent: 52), .good)
        XCTAssertEqual(WHO5Band.band(forPercent: 50), .low)
        XCTAssertEqual(WHO5Band.band(forPercent: 29), .low)
        XCTAssertEqual(WHO5Band.band(forPercent: 28), .veryLow)
        XCTAssertEqual(WHO5Band.band(forPercent: 0), .veryLow)
    }

    func testResult() throws {
        let r = try WHO5Result(answers: [2, 2, 2, 1, 1])
        XCTAssertEqual(r.percentScore, 32)
        XCTAssertEqual(r.rawScore, 8)
        XCTAssertEqual(r.band, .low)
        XCTAssertThrowsError(try WHO5Result(answers: [9, 9, 9, 9, 9]))
    }
}

final class FlourishTests: XCTestCase {
    let library = TestSupport.library
    let cal = TestSupport.calendar()

    func testEmptyDataIsZero() {
        let s = FlourishCalculator.snapshot(data: AppData(), library: library, now: Date(), calendar: cal)
        XCTAssertEqual(s.overall, 0)
        XCTAssertNil(s.averageMood)
        for d in WellnessDimension.allCases { XCTAssertEqual(s.score(d), 0) }
    }

    func testScoresScaleWithActivityAndIgnoreOldEntries() throws {
        let now = TestSupport.date(2026, 11, 20, 12, calendar: cal)
        var data = AppData()
        for i in 0..<3 {
            data.record(session: PracticeSession(date: now.addingTimeInterval(Double(-i) * 3_600), practiceID: "move-your-body"))
        }
        data.record(session: PracticeSession(date: now.addingTimeInterval(-3_600), practiceID: "breath-prayer"))
        data.record(session: PracticeSession(date: now.addingTimeInterval(-30 * 86_400), practiceID: "reach-out"))
        data.checkIns = [CheckIn(date: now.addingTimeInterval(-7_200), mood: 5, factors: [.connected])]
        data.reframes = [ReframeEntry(date: now.addingTimeInterval(-60), thought: "x",
                                      result: ReframeEngine(library: library).reframe("x"))]
        let s = FlourishCalculator.snapshot(data: data, library: library, now: now, calendar: cal)
        XCTAssertEqual(s.score(.physical), 100)
        XCTAssertEqual(s.score(.spiritual), 33)
        XCTAssertEqual(s.score(.social), 17, "0.5 points from a 'connected' check-in; the 30-day-old session is ignored")
        XCTAssertEqual(s.score(.mental), 33)
        XCTAssertEqual(s.score(.emotional), 60, "mood 5 → 100 × 0.6 + 0 × 0.4")
        XCTAssertEqual(s.averageMood, 5)
        XCTAssertEqual(s.focusDimension, .purpose)
        for d in WellnessDimension.allCases { XCTAssertTrue((0...100).contains(s.score(d))) }
    }
}

final class MoodAnalyticsTests: XCTestCase {
    let cal = TestSupport.calendar()

    private func checkIn(daysAgo: Double, mood: Int, from now: Date) -> CheckIn {
        CheckIn(date: now.addingTimeInterval(-daysAgo * 86_400), mood: mood)
    }

    func testEWMA() {
        let now = Date()
        XCTAssertNil(MoodAnalytics.ewma([]))
        let values = [checkIn(daysAgo: 2, mood: 2, from: now), checkIn(daysAgo: 1, mood: 4, from: now)]
        XCTAssertEqual(MoodAnalytics.ewma(values, alpha: 0.5)!, 3.0, accuracy: 1e-9)
        // Order of input doesn't matter.
        XCTAssertEqual(MoodAnalytics.ewma(values.reversed(), alpha: 0.5)!, 3.0, accuracy: 1e-9)
    }

    func testTrend() {
        let now = TestSupport.date(2026, 11, 20, 12, calendar: cal)
        let improving = [9.0, 10, 1, 2].enumerated().map { checkIn(daysAgo: $0.element, mood: $0.offset < 2 ? 2 : 4, from: now) }
        XCTAssertEqual(MoodAnalytics.trend(improving, now: now, calendar: cal), .improving)
        let declining = [9.0, 10, 1, 2].enumerated().map { checkIn(daysAgo: $0.element, mood: $0.offset < 2 ? 5 : 3, from: now) }
        XCTAssertEqual(MoodAnalytics.trend(declining, now: now, calendar: cal), .declining)
        let steady = [9.0, 10, 1, 2].map { checkIn(daysAgo: $0, mood: 3, from: now) }
        XCTAssertEqual(MoodAnalytics.trend(steady, now: now, calendar: cal), .steady)
        XCTAssertEqual(MoodAnalytics.trend([checkIn(daysAgo: 1, mood: 3, from: now)], now: now, calendar: cal), .notEnoughData)
    }

    func testSustainedLowMood() {
        let now = Date()
        let low = (1...4).map { checkIn(daysAgo: Double($0), mood: 1, from: now) }
        XCTAssertTrue(MoodAnalytics.sustainedLowMood(low, now: now, calendar: cal))
        let mixed = low + (1...6).map { checkIn(daysAgo: Double($0) + 0.5, mood: 4, from: now) }
        XCTAssertFalse(MoodAnalytics.sustainedLowMood(mixed, now: now, calendar: cal))
        let old = (20...25).map { checkIn(daysAgo: Double($0), mood: 1, from: now) }
        XCTAssertFalse(MoodAnalytics.sustainedLowMood(old, now: now, calendar: cal))
    }

    func testStreak() {
        let now = TestSupport.date(2026, 11, 20, 9, calendar: cal)
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now)! }
        XCTAssertEqual(MoodAnalytics.streak(activityDates: [], now: now, calendar: cal), 0)
        XCTAssertEqual(MoodAnalytics.streak(activityDates: [day(0), day(1), day(2)], now: now, calendar: cal), 3)
        XCTAssertEqual(MoodAnalytics.streak(activityDates: [day(1), day(2)], now: now, calendar: cal), 2, "yesterday keeps the streak alive")
        XCTAssertEqual(MoodAnalytics.streak(activityDates: [day(2), day(3)], now: now, calendar: cal), 0)
        XCTAssertEqual(MoodAnalytics.streak(activityDates: [day(0), day(0), day(2)], now: now, calendar: cal), 1)
    }

    func testDailyAverages() {
        let now = TestSupport.date(2026, 11, 20, 18, calendar: cal)
        let values = [CheckIn(date: now, mood: 2), CheckIn(date: now.addingTimeInterval(-3_600), mood: 4),
                      CheckIn(date: now.addingTimeInterval(-40 * 86_400), mood: 1)]
        let days = MoodAnalytics.dailyAverages(values, days: 7, now: now, calendar: cal)
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days.first?.average, 3)
    }
}
