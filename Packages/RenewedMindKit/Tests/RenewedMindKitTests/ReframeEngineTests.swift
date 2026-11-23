import XCTest
@testable import RenewedMindKit

final class ReframeEngineTests: XCTestCase {
    let library = TestSupport.library
    lazy var engine = ReframeEngine(library: library)

    let samples = [
        "I always mess everything up and I'm a failure.",
        "Nobody likes me. They probably think I'm annoying.",
        "I'm going to fail this exam and my life will be ruined.",
        "I should be over my dad's death by now.",
        "God doesn't care about me anymore.",
        "I can't sleep and tomorrow is going to be a disaster.",
        "Everyone else is married and happy and I'm behind.",
        "I'm so angry at my sister, it's all her fault.",
        "I'm overwhelmed with work and I can't keep up.",
        "My chronic pain makes me feel useless.",
        "I had a hard day.",
        "😞😞😞",
        "",
    ]

    func testResultsAreCompleteForManyInputs() {
        for text in samples {
            let r = engine.reframe(text)
            XCTAssertEqual(r.source, .offline)
            XCTAssertFalse(r.validation.isEmpty, text)
            XCTAssertFalse(r.balancedThought.isEmpty, text)
            XCTAssertFalse(r.nextStep.isEmpty, text)
            XCTAssertFalse(r.personalAffirmation.isEmpty, text)
            XCTAssertNotNil(library.affirmation(id: r.affirmationID), text)
            XCTAssertTrue((1...3).contains(r.questions.count), text)
            if let practice = r.suggestedPracticeID { XCTAssertNotNil(library.practice(id: practice)) }
            for field in [r.validation, r.balancedThought, r.nextStep] + r.questions {
                XCTAssertFalse(field.contains("{") || field.contains("}") || field.contains("  "), "template artifact: \(field)")
            }
        }
    }

    func testDeterministic() {
        for text in samples {
            XCTAssertEqual(engine.reframe(text), engine.reframe(text))
        }
    }

    func testAnxietyThoughtGetsAnxietyScripture() {
        let r = engine.reframe("I'm so anxious and worried about everything tomorrow")
        var allowed = Concern.anxiety.guidance.affirmationIDs
        allowed += r.distortions.map { $0.distortion.info.affirmationID }
        XCTAssertTrue(allowed.contains(r.affirmationID), "got \(r.affirmationID)")
        XCTAssertEqual(r.suggestedPracticeID, "breath-prayer")
        XCTAssertEqual(r.concerns.first, .anxiety)
    }

    func testDistortionReframeIsUsed() {
        let r = engine.reframe("Nothing ever works out")
        XCTAssertEqual(r.distortions.first?.distortion, .overgeneralization)
        let reframes = CognitiveDistortion.overgeneralization.info.reframes
        XCTAssertTrue(reframes.contains { r.balancedThought.hasPrefix($0) }, r.balancedThought)
        // No concern detected → the distortion's linked verse.
        XCTAssertEqual(r.affirmationID, CognitiveDistortion.overgeneralization.info.affirmationID)
    }

    func testNeutralThoughtUsesGeneralGuidance() {
        let r = engine.reframe("I had a hard day.")
        XCTAssertTrue(r.distortions.isEmpty)
        XCTAssertTrue(r.balancedThought.hasPrefix("I'm noticing a painful thought"))
        XCTAssertEqual(r.crisisLevel, CrisisLevel.none)
    }

    func testUrgentCrisisReturnsSafetyResult() {
        let r = engine.reframe("I want to end my life")
        XCTAssertEqual(r.crisisLevel, .urgent)
        XCTAssertTrue(r.distortions.isEmpty)
        XCTAssertTrue(r.questions.isEmpty)
        XCTAssertEqual(r.affirmationID, ReframeEngine.crisisAffirmationID)
        XCTAssertEqual(r.suggestedPracticeID, "grounding-54321")
    }

    func testConcernLevelKeepsReframeButFlagsResources() {
        let r = engine.reframe("I can't go on like this, everything is hopeless")
        XCTAssertEqual(r.crisisLevel, .concern)
        XCTAssertFalse(r.questions.isEmpty)
        XCTAssertEqual(r.concerns.first, .hopelessness)
    }

    func testQuestionsAreUniqueAndCapped() {
        let r = engine.reframe("I always fail, I'm a loser, I should be better, they all think I'm stupid")
        XCTAssertEqual(Set(r.questions).count, r.questions.count)
        XCTAssertLessThanOrEqual(r.questions.count, 3)
    }

    func testVeryLongThought() {
        let text = String(repeating: "I always feel anxious and alone. ", count: 300)
        let r = engine.reframe(text)
        XCTAssertFalse(r.balancedThought.isEmpty)
    }

    func testResultRoundTripsThroughJSON() throws {
        let r = engine.reframe("I'm such a failure and nobody cares")
        let data = try DataStore.makeEncoder().encode(r)
        let decoded = try DataStore.makeDecoder().decode(ReframeResult.self, from: data)
        XCTAssertEqual(decoded, r)
    }
}

extension ReframeEngineTests {
    func testScriptureComesFromTheConcernsCuratedList() {
        let cases: [(String, Concern)] = [
            ("I feel so guilty and ashamed of what I did", .guilt),
            ("I miss my grandmother so much since she passed away", .grief),
            ("I can't sleep, I'm awake all night", .sleep),
            ("Nobody at church likes me", .loneliness),
            ("I'm going to fail my nursing exam", .anxiety),
        ]
        for (text, concern) in cases {
            let r = engine.reframe(text)
            XCTAssertEqual(r.concerns.first, concern, text)
            let allowed = concern.guidance.affirmationIDs + r.distortions.map { $0.distortion.info.affirmationID }
            XCTAssertTrue(allowed.contains(r.affirmationID), "\(text) → \(r.affirmationID)")
        }
    }
}
