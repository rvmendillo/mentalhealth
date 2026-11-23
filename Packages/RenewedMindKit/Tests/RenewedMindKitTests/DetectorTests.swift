import XCTest
@testable import RenewedMindKit

final class CrisisDetectorTests: XCTestCase {
    func testUrgentPhrasesAreDetected() {
        let urgent = [
            "I want to kill myself",
            "I've been thinking about suicide a lot",
            "honestly i dont want to live anymore",
            "Everyone would be better off without me",
            "I want to end my life",
            "I keep cutting myself when it gets bad",
            "thinking about self-harm again",
            "I wish I were dead",
            "there's no reason to live",
            "I WANT TO DIE",
            "I don’t want to be alive anymore",
            "I feel suicidal tonight",
            "I'm going to take my own life",
            "sometimes I want to unalive myself",
            "I'm planning to hurt someone",
        ]
        for text in urgent {
            XCTAssertEqual(CrisisDetector.assess(text).level, .urgent, text)
        }
    }

    func testConcernPhrasesAreDetected() {
        let concern = [
            "I can't go on like this",
            "What's the point of living",
            "my husband hits me when he's angry",
            "I wish I'd never been born",
            "I can't take it anymore",
            "I'm not safe at home",
            "I just want to disappear",
            "There's no way out",
        ]
        for text in concern {
            XCTAssertEqual(CrisisDetector.assess(text).level, .concern, text)
        }
    }

    func testCommonIdiomsAreNotFlagged() {
        let benign = [
            "This traffic is killing me",
            "I'm dying to see that movie",
            "I killed it at my presentation!",
            "That joke killed me",
            "I'm going to die of embarrassment",
            "My phone battery died again",
            "I ran 5 kms today and felt great",
            "I feel anxious about my exam",
            "I'm so tired of this rain",
            "I hate Mondays",
            "",
            "   ",
        ]
        for text in benign {
            XCTAssertEqual(CrisisDetector.assess(text).level, .none, text)
        }
    }

    func testAssessmentReportsCategoriesAndPhrases() {
        let result = CrisisDetector.assess("I want to die and I keep hurting myself")
        XCTAssertEqual(result.level, .urgent)
        XCTAssertTrue(result.categories.contains(.suicide))
        XCTAssertTrue(result.categories.contains(.selfHarm))
        XCTAssertFalse(result.matchedPhrases.isEmpty)
    }
}

final class DistortionDetectorTests: XCTestCase {
    private func detected(_ text: String) -> [CognitiveDistortion] {
        DistortionDetector.detect(in: text).map(\.distortion)
    }

    func testEachPatternIsDetected() {
        let cases: [(String, CognitiveDistortion)] = [
            ("If it's not perfect, it's worthless.", .allOrNothing),
            ("I always mess everything up.", .overgeneralization),
            ("All I can think about is the one mistake I made.", .mentalFilter),
            ("I got the promotion but it was just luck.", .discountingPositive),
            ("They probably think I'm boring.", .mindReading),
            ("I'm going to fail this exam.", .fortuneTelling),
            ("If I lose this job my life is over.", .catastrophizing),
            ("I feel like a failure.", .emotionalReasoning),
            ("I should be over this by now.", .shouldStatements),
            ("I'm such an idiot.", .labeling),
            ("It's all my fault that they divorced.", .personalization),
            ("Everyone else is so much happier than me.", .comparison),
        ]
        for (text, expected) in cases {
            XCTAssertTrue(detected(text).contains(expected), "\(expected) not found in: \(text) → \(detected(text))")
        }
    }

    func testCurlyApostrophesAreHandled() {
        XCTAssertTrue(detected("I’m such a failure").contains(.labeling))
        XCTAssertTrue(detected("It’s all my fault").contains(.personalization))
    }

    func testNeutralTextHasNoPatterns() {
        XCTAssertEqual(detected("I went to the store and bought apples."), [])
        XCTAssertEqual(detected("I'm grateful for my family and my church."), [])
        XCTAssertEqual(detected(""), [])
    }

    func testSingleWeakSignalIsNotEnough() {
        // "everyone" alone carries weight 1, below the threshold of 2.
        XCTAssertFalse(detected("Everyone came to the party.").contains(.overgeneralization))
    }

    func testLimitAndOrdering() {
        let text = "I always ruin everything, I'm a failure, I should be perfect, and they all think I'm stupid. It's all my fault."
        let results = DistortionDetector.detect(in: text)
        XCTAssertLessThanOrEqual(results.count, 3)
        XCTAssertEqual(DistortionDetector.detect(in: text, limit: 1).count, 1)
        XCTAssertEqual(Set(results.map(\.distortion)).count, results.count, "no duplicates")
        let normalized = TextTools.normalize(text)
        for r in results { XCTAssertTrue(normalized.contains(r.evidence), r.evidence) }
    }

    func testVeryLongInputIsHandled() {
        let long = String(repeating: "I always feel like nobody cares. ", count: 400)
        let start = Date()
        let results = DistortionDetector.detect(in: long)
        XCTAssertLessThan(Date().timeIntervalSince(start), 3.0)
        XCTAssertFalse(results.isEmpty)
    }
}

final class ConcernClassifierTests: XCTestCase {
    func testConcerns() {
        let cases: [(String, Concern)] = [
            ("I'm so anxious about tomorrow's interview", .anxiety),
            ("I feel so alone, nobody cares", .loneliness),
            ("I miss my mom since she passed away", .grief),
            ("It feels like God doesn't hear my prayers", .faith),
            ("I can't sleep again", .sleep),
            ("I'm worthless", .worth),
            ("I feel so guilty about what I said", .guilt),
            ("I'm furious with my brother", .anger),
            ("I'm overwhelmed with everything at work", .overwhelm),
            ("Everyone else seems happier on social media", .comparison),
            ("My chronic pain is getting worse", .health),
            ("Everything feels hopeless", .hopelessness),
            ("I failed my driving test", .failure),
        ]
        for (text, expected) in cases {
            XCTAssertEqual(ConcernClassifier.classify(text).first, expected, text)
        }
    }

    func testNoConcernForNeutralText() {
        XCTAssertEqual(ConcernClassifier.classify("I had a nice lunch with a friend"), [])
        XCTAssertEqual(ConcernClassifier.classify(""), [])
    }

    func testLimit() {
        let text = "I'm anxious and lonely and overwhelmed and I can't sleep"
        XCTAssertEqual(ConcernClassifier.classify(text).count, 2)
        XCTAssertEqual(ConcernClassifier.classify(text, limit: 4).count, 4)
    }
}

final class TextToolsTests: XCTestCase {
    func testNormalize() {
        XCTAssertEqual(TextTools.normalize("  I’M   “Fine”\n—really  "), "i'm \"fine\" - really")
    }

    func testStableHashIsStable() {
        XCTAssertEqual(TextTools.stableHash("renewed mind"), TextTools.stableHash("renewed mind"))
        XCTAssertNotEqual(TextTools.stableHash("a"), TextTools.stableHash("b"))
        // FNV-1a reference value for the empty string.
        XCTAssertEqual(TextTools.stableHash(""), 0xcbf2_9ce4_8422_2325)
    }

    func testClean() {
        XCTAssertEqual(TextTools.clean("  hello   world  "), "hello world")
        let long = String(repeating: "word ", count: 100)
        let cleaned = TextTools.clean(long, maxLength: 20)
        XCTAssertLessThanOrEqual(cleaned.count, 21)
        XCTAssertTrue(cleaned.hasSuffix("…"))
    }

    func testPick() {
        XCTAssertNil(TextTools.pick([Int](), seed: "x"))
        XCTAssertEqual(TextTools.pick([1, 2, 3], seed: "x"), TextTools.pick([1, 2, 3], seed: "x"))
    }
}
