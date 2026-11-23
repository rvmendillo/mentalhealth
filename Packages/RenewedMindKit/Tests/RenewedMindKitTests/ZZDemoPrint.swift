import XCTest
@testable import RenewedMindKit

final class ZZDemoPrint: XCTestCase {
    func testPrintSamples() throws {
        guard ProcessInfo.processInfo.environment["RM_DEMO"] != nil else { throw XCTSkip("demo only") }
        let lib = TestSupport.library
        let engine = ReframeEngine(library: lib)
        for t in ["I always mess everything up and I'm such a failure.",
                  "Nobody at church likes me. They probably think I'm weird.",
                  "I'm going to fail my nursing exam and disappoint my parents.",
                  "God feels so far away. My prayers aren't answered.",
                  "I'm so anxious I can't sleep, what if I lose my job?"] {
            let r = engine.reframe(t)
            let a = lib.affirmation(id: r.affirmationID)!
            print("\n=== THOUGHT: \(t)")
            print("VALIDATION: \(r.validation)")
            print("PATTERNS: \(r.distortions.map { "\($0.distortion.info.name) [\($0.evidence)]" })")
            print("QUESTIONS: \(r.questions)")
            print("BALANCED: \(r.balancedThought)")
            print("SCRIPTURE: \(a.reference) — \(a.verse)")
            print("WORD: \(a.wordStudy.lemma) (\(a.wordStudy.transliteration), \(a.wordStudy.strongs)) — \(a.wordStudy.meaning)")
            print("AFFIRMATION: \(r.personalAffirmation)")
            print("NEXT: \(r.nextStep) [\(r.suggestedPracticeID ?? "-")]")
        }
    }
}
