import XCTest
@testable import RenewedMindKit

final class ContentTests: XCTestCase {
    let library = TestSupport.library

    private let referencePattern = try! NSRegularExpression(
        pattern: #"^(?:[1-3] )?[A-Z][a-z]+(?: [A-Z][a-z]+)* \d+:\d+(?:–\d+)?$"#)

    private func isValidReference(_ ref: String) -> Bool {
        referencePattern.firstMatch(in: ref, range: NSRange(ref.startIndex..., in: ref)) != nil
    }

    private func containsScript(_ text: String, _ ranges: [ClosedRange<UInt32>]) -> Bool {
        text.unicodeScalars.contains { scalar in ranges.contains { $0.contains(scalar.value) } }
    }

    func testCounts() {
        XCTAssertGreaterThanOrEqual(library.affirmations.count, 80)
        XCTAssertEqual(library.practices.count, 20)
        XCTAssertGreaterThanOrEqual(library.citations.count, 40)
        XCTAssertGreaterThanOrEqual(library.etymologies.count, 20)
    }

    func testEveryThemeHasAtLeastFourAffirmations() {
        for theme in Theme.allCases {
            XCTAssertGreaterThanOrEqual(library.affirmations(for: theme).count, 4, "\(theme)")
        }
    }

    func testAffirmationFieldsAreCompleteAndConsistent() {
        let hebrew: [ClosedRange<UInt32>] = [0x0590...0x05FF]
        let greek: [ClosedRange<UInt32>] = [0x0370...0x03FF, 0x1F00...0x1FFF]
        for a in library.affirmations {
            XCTAssertTrue(a.id.hasPrefix(a.theme.rawValue + "-"), a.id)
            XCTAssertTrue(isValidReference(a.reference), "\(a.id): \(a.reference)")
            for text in [a.affirmation, a.verse, a.reflection, a.wordStudy.meaning, a.wordStudy.insight,
                         a.wordStudy.transliteration, a.wordStudy.english, a.wordStudy.lemma] {
                XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, a.id)
                XCTAssertFalse(text.contains("{") || text.contains("}"), "template braces in \(a.id)")
            }
            let ws = a.wordStudy
            XCTAssertNotNil(ws.strongs.range(of: #"^[HG][1-9]\d{0,4}$"#, options: .regularExpression), a.id)
            if ws.strongs.hasPrefix("H") {
                XCTAssertEqual(ws.language, .hebrew, a.id)
                XCTAssertTrue(containsScript(ws.lemma, hebrew), "\(a.id) lemma should be Hebrew")
            } else {
                XCTAssertEqual(ws.language, .greek, a.id)
                XCTAssertTrue(containsScript(ws.lemma, greek), "\(a.id) lemma should be Greek")
            }
            XCTAssertTrue(a.verse.lowercased().contains(ws.english.lowercased()),
                          "\(a.id): gloss '\(ws.english)' should appear in the verse")
            XCTAssertTrue(a.affirmation.hasSuffix(".") || a.affirmation.hasSuffix("!"), a.id)
            XCTAssertTrue(a.reflection.hasSuffix("?") || a.reflection.hasSuffix("."), a.id)
        }
    }

    func testVerseTextUsesBereanStandardBibleStyle() {
        // Spot-check exact Berean Standard Bible wording for well-known verses.
        XCTAssertEqual(library.affirmation(id: "rest-matthew-11-28")?.verse,
                       "Come to Me, all you who are weary and burdened, and I will give you rest.")
        XCTAssertEqual(library.affirmation(id: "comfort-john-11-35")?.verse, "Jesus wept.")
        XCTAssertEqual(library.affirmation(id: "peace-1peter-5-7")?.verse,
                       "Cast all your anxiety on Him, because He cares for you.")
        XCTAssertEqual(library.affirmation(id: "strength-philippians-4-13")?.verse,
                       "I can do all things through Christ who gives me strength.")
    }

    func testWordStudySpotChecks() {
        let romans = library.affirmation(id: "renewal-romans-12-2")!.wordStudy
        XCTAssertEqual(romans.strongs, "G3339")
        XCTAssertEqual(romans.lemma, "μεταμορφόω")
        let isaiah = library.affirmation(id: "peace-isaiah-26-3")!.wordStudy
        XCTAssertEqual(isaiah.strongs, "H7965")
        XCTAssertEqual(isaiah.lemma, "שָׁלוֹם")
        XCTAssertEqual(isaiah.transliteration, "shalom")
    }

    func testPracticesAreComplete() {
        for p in library.practices {
            XCTAssertFalse(p.title.isEmpty)
            XCTAssertGreaterThan(p.minutes, 0, p.id)
            XCTAssertFalse(p.steps.isEmpty, p.id)
            XCTAssertFalse(p.needs.isEmpty, p.id)
            XCTAssertFalse(p.verse.isEmpty, p.id)
            XCTAssertTrue(isValidReference(p.reference), "\(p.id): \(p.reference)")
            XCTAssertFalse(p.citations.isEmpty, p.id)
            for id in p.citations { XCTAssertNotNil(library.citation(id: id), "\(p.id) cites missing \(id)") }
            switch p.kind {
            case .breathing:
                let pattern = try! XCTUnwrap(p.breathing, p.id)
                XCTAssertGreaterThan(pattern.inhale, 0)
                XCTAssertGreaterThan(pattern.exhale, 0)
            case .journal:
                XCTAssertFalse(p.prompts.isEmpty, p.id)
            case .checklist:
                XCTAssertFalse(p.checklist.isEmpty, p.id)
            case .timer, .guided:
                break
            }
        }
    }

    func testBreathingPatternsMatchTheResearch() {
        let breathPrayer = library.practice(id: "breath-prayer")!.breathing!
        XCTAssertEqual(breathPrayer.breathsPerMinute, 6, accuracy: 0.01, "resonance breathing ≈ 6 breaths/min")
        let sighing = library.practice(id: "cyclic-sighing")!.breathing!
        XCTAssertGreaterThan(sighing.topUp, 0, "cyclic sighing has a second inhale")
        XCTAssertGreaterThan(sighing.exhale, sighing.inhale + sighing.topUp, "exhale is longer than inhales")
    }

    func testCitations() {
        for c in library.citations {
            XCTAssertTrue((1900...2026).contains(c.year), c.id)
            XCTAssertFalse(c.short.isEmpty)
            XCTAssertTrue(c.short.hasSuffix(String(c.year)), c.id)
            if let doi = c.doi {
                XCTAssertNotNil(doi.range(of: #"^10\.\d{4,9}/\S+$"#, options: .regularExpression), c.id)
                XCTAssertEqual(c.url?.absoluteString, "https://doi.org/\(doi)")
            }
            XCTAssertTrue(c.formatted.contains(c.title))
        }
        XCTAssertEqual(library.citation(id: "emmons2003")?.short, "Emmons & McCullough, 2003")
        XCTAssertEqual(library.citation(id: "king2001")?.short, "King, 2001")
        XCTAssertEqual(library.citation(id: "seligman2005")?.short, "Seligman et al., 2005")
    }

    func testEtymologies() {
        var ids = Set<String>()
        for e in library.etymologies {
            XCTAssertTrue(ids.insert(e.id).inserted, "duplicate \(e.id)")
            XCTAssertFalse(e.origin.isEmpty)
            XCTAssertFalse(e.insight.isEmpty)
            if let ref = e.reference {
                XCTAssertTrue(isValidReference(ref), ref)
                XCTAssertFalse((e.verse ?? "").isEmpty, e.id)
            }
        }
        let sincere = library.etymologies.first { $0.id == "sincere" }
        XCTAssertNotNil(sincere?.insight.range(of: "myth"), "the sine cera myth is explicitly corrected")
    }

    func testDistortionCatalogLinksToRealContent() {
        for d in CognitiveDistortion.allCases {
            let info = d.info
            XCTAssertNotNil(library.affirmation(id: info.affirmationID), "\(d) → \(info.affirmationID)")
            XCTAssertGreaterThanOrEqual(info.reframes.count, 2)
            XCTAssertTrue(info.question.hasSuffix("?"), "\(d)")
        }
    }

    func testConcernCatalogLinksToRealContent() {
        for concern in Concern.allCases {
            let g = concern.guidance
            XCTAssertNotNil(library.practice(id: g.practiceID), "\(concern) → \(g.practiceID)")
            XCTAssertGreaterThanOrEqual(g.validations.count, 2)
            XCTAssertFalse(g.themes.flatMap { library.affirmations(for: $0) }.isEmpty)
            XCTAssertGreaterThanOrEqual(g.affirmationIDs.count, 4, "\(concern)")
            for id in g.affirmationIDs { XCTAssertNotNil(library.affirmation(id: id), "\(concern) → \(id)") }
            XCTAssertEqual(Set(g.affirmationIDs).count, g.affirmationIDs.count, "\(concern) has duplicate verses")
        }
        for id in ConcernCatalog.general.affirmationIDs { XCTAssertNotNil(library.affirmation(id: id), id) }
        XCTAssertNotNil(library.practice(id: ConcernCatalog.general.practiceID))
        XCTAssertNotNil(library.affirmation(id: ReframeEngine.crisisAffirmationID))
        XCTAssertNotNil(library.practice(id: "grounding-54321"))
    }

    func testDuplicateIDsAreRejected() {
        let a = library.affirmations[0]
        XCTAssertThrowsError(try ContentLibrary(affirmations: [a, a], practices: library.practices,
                                                citations: [], etymologies: []))
    }

    func testDailyAffirmationIsStableAndRotates() {
        let cal = TestSupport.calendar()
        let morning = TestSupport.date(2026, 11, 22, 7, calendar: cal)
        let night = TestSupport.date(2026, 11, 22, 23, 59, calendar: cal)
        XCTAssertEqual(library.dailyAffirmation(for: morning, calendar: cal).id,
                       library.dailyAffirmation(for: night, calendar: cal).id)
        let next = TestSupport.date(2026, 11, 23, 0, 1, calendar: cal)
        XCTAssertNotEqual(library.dailyAffirmation(for: night, calendar: cal).id,
                          library.dailyAffirmation(for: next, calendar: cal).id)
    }

    func testDailyAffirmationsCoverEveryAffirmationOncePerCycle() {
        let cal = TestSupport.calendar("UTC")
        let start = TestSupport.date(2026, 1, 1, 12, calendar: cal)
        let count = library.affirmations.count
        var seen = Set<String>()
        var sameThemeNeighbours = 0
        var previous: Affirmation?
        for day in 0..<count {
            let date = cal.date(byAdding: .day, value: day, to: start)!
            let a = library.dailyAffirmation(for: date, calendar: cal)
            seen.insert(a.id)
            if let previous, previous.theme == a.theme { sameThemeNeighbours += 1 }
            previous = a
        }
        XCTAssertEqual(seen.count, count, "a full cycle visits every affirmation exactly once")
        XCTAssertLessThanOrEqual(sameThemeNeighbours, 2, "themes are interleaved day to day")
    }

    func testDayNumberHandlesDaylightSaving() {
        let cal = TestSupport.calendar("America/New_York")
        // DST began 8 March 2026 in the US.
        let before = TestSupport.date(2026, 3, 7, 23, 30, calendar: cal)
        let after = TestSupport.date(2026, 3, 8, 0, 30, calendar: cal)
        let later = TestSupport.date(2026, 3, 9, 0, 30, calendar: cal)
        let n = ContentLibrary.dayNumber(for: before, calendar: cal)
        XCTAssertEqual(ContentLibrary.dayNumber(for: after, calendar: cal), n + 1)
        XCTAssertEqual(ContentLibrary.dayNumber(for: later, calendar: cal), n + 2)
    }

    func testSearch() {
        XCTAssertTrue(library.search("shalom").contains { $0.id == "peace-isaiah-26-3" })
        XCTAssertTrue(library.search("Romans 12:2").contains { $0.id == "renewal-romans-12-2" })
        XCTAssertTrue(library.search("ANXIETY").contains { $0.id == "peace-1peter-5-7" })
        XCTAssertEqual(library.search("   ").count, library.affirmations.count)
        XCTAssertTrue(library.search("zzzz-not-a-word").isEmpty)
    }
}
