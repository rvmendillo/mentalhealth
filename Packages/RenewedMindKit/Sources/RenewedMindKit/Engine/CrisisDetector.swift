import Foundation

public enum CrisisLevel: Int, Codable, Sendable, Comparable {
    /// No safety concern detected.
    case none = 0
    /// Possible risk (passive hopelessness, abuse, thoughts of harming others): show resources alongside the reframe.
    case concern = 1
    /// Explicit risk of suicide or self-harm: lead with crisis resources instead of a reframe.
    case urgent = 2

    public static func < (lhs: CrisisLevel, rhs: CrisisLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum CrisisCategory: String, Codable, Sendable {
    case suicide, selfHarm, harmToOthers, abuse, hopelessness
}

public struct CrisisAssessment: Equatable, Sendable {
    public let level: CrisisLevel
    public let categories: [CrisisCategory]
    public let matchedPhrases: [String]

    public static let none = CrisisAssessment(level: .none, categories: [], matchedPhrases: [])
}

/// Conservative, keyword-based safety screen. It runs on-device before any AI call.
///
/// It is intentionally sensitive: a false alarm only shows support resources, while a miss could
/// leave someone without help. It is not a clinical risk assessment.
public enum CrisisDetector {
    private struct Rule {
        let pattern: WeightedPattern
        let level: CrisisLevel
        let category: CrisisCategory
        init(_ pattern: String, _ level: CrisisLevel, _ category: CrisisCategory) {
            self.pattern = WeightedPattern(pattern, weight: 1)
            self.level = level
            self.category = category
        }
    }

    private static let rules: [Rule] = [
        // Suicide — explicit
        Rule(#"\b(kill|killing|killed) (myself|my self|meself)\b"#, .urgent, .suicide),
        Rule(#"\b(end|ending|take|taking) (my|my own) life\b"#, .urgent, .suicide),
        Rule(#"\bend it all\b"#, .urgent, .suicide),
        Rule(#"\bsuicid(e|al)\b"#, .urgent, .suicide),
        Rule(#"\b(want|wanted|wanting|ready|plan|planning) to die\b"#, .urgent, .suicide),
        Rule(#"\bwanna die\b"#, .urgent, .suicide),
        Rule(#"\bwish (i was|i were|i'd be|to be) dead\b"#, .urgent, .suicide),
        Rule(#"\bwish i (could|would) (just )?die\b"#, .urgent, .suicide),
        Rule(#"\bbetter off dead\b"#, .urgent, .suicide),
        Rule(#"\b(everyone|everybody|they|the world|my family|people) (would|will|'d) be better off without me\b"#, .urgent, .suicide),
        Rule(#"\bbetter off without me\b"#, .urgent, .suicide),
        Rule(#"\b(don't|dont|do not|no longer|not) want to (live|be alive|exist|wake up)( anymore)?\b"#, .urgent, .suicide),
        Rule(#"\b(no|zero) reason to (live|go on|keep going|be alive)\b"#, .urgent, .suicide),
        Rule(#"\bnothing (left )?to live for\b"#, .urgent, .suicide),
        Rule(#"\bunalive\b"#, .urgent, .suicide),
        Rule(#"\b(want to|wanna|going to|gonna|about to) kms\b"#, .urgent, .suicide),
        Rule(#"\b(overdose|overdosing)\b"#, .urgent, .suicide),
        Rule(#"\b(jump|jumping) off (a|the) (bridge|building|roof)\b"#, .urgent, .suicide),
        Rule(#"\bhang myself\b"#, .urgent, .suicide),
        // Self-harm
        Rule(#"\b(hurt|hurting|harm|harming|cut|cutting|burn|burning|starve|starving) (myself|my self)\b"#, .urgent, .selfHarm),
        Rule(#"\bself[- ]?harm(ing)?\b"#, .urgent, .selfHarm),
        // Harm to others
        Rule(#"\b(want|going|plan|planning) to (kill|hurt|harm|shoot|stab) (him|her|them|someone|somebody|people|my \w+)\b"#, .urgent, .harmToOthers),
        // Abuse / safety at home
        Rule(#"\b(he|she|they|my (husband|wife|partner|boyfriend|girlfriend|dad|father|mom|mother|stepdad|stepmom|parent|parents|ex)) (hits|hit|beats|beat|chokes|choked|strangled|abuses|abused|threatens|threatened|hurts) me\b"#, .concern, .abuse),
        Rule(#"\b(being|been|am being|i'm being) (abused|hit|beaten|assaulted|raped)\b"#, .concern, .abuse),
        Rule(#"\bnot safe (at home|with him|with her|with them)\b"#, .concern, .abuse),
        Rule(#"\bafraid (of|to go) home\b"#, .concern, .abuse),
        // Hopelessness / passive ideation
        Rule(#"\bcan't go on\b|\bcannot go on\b|\bcant go on\b"#, .concern, .hopelessness),
        Rule(#"\b(wish|wished) i( was| were| had|'d) never (been )?born\b"#, .concern, .hopelessness),
        Rule(#"\b(wish|want) (i could|to) (just )?disappear( forever)?\b"#, .concern, .hopelessness),
        Rule(#"\b(what's|whats|what is) the point (of|in) (living|life|going on|anything)\b"#, .concern, .hopelessness),
        Rule(#"\bno point (in )?(living|life|going on|trying anymore)\b"#, .concern, .hopelessness),
        Rule(#"\b(tired|sick) of (living|being alive|life)\b"#, .concern, .hopelessness),
        Rule(#"\bcan't (take|do) (it|this) anymore\b|\bcant (take|do) (it|this) anymore\b"#, .concern, .hopelessness),
        Rule(#"\bgive up on (life|everything|myself)\b"#, .concern, .hopelessness),
        Rule(#"\bno way out\b"#, .concern, .hopelessness),
    ]

    public static func assess(_ text: String) -> CrisisAssessment {
        let normalized = TextTools.normalize(text)
        guard !normalized.isEmpty else { return .none }
        var level: CrisisLevel = .none
        var categories: [CrisisCategory] = []
        var phrases: [String] = []
        for rule in rules {
            if let match = rule.pattern.firstMatch(in: normalized) {
                level = max(level, rule.level)
                if !categories.contains(rule.category) { categories.append(rule.category) }
                if !phrases.contains(match) { phrases.append(match) }
            }
        }
        return CrisisAssessment(level: level, categories: categories, matchedPhrases: phrases)
    }
}
