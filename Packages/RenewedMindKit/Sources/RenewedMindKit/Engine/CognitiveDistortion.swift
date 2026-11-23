import Foundation

/// Common unhelpful thinking patterns from cognitive behavioral therapy (Beck, 1979; Burns, 1980).
public enum CognitiveDistortion: String, Codable, CaseIterable, Sendable, Identifiable {
    case allOrNothing
    case overgeneralization
    case mentalFilter
    case discountingPositive
    case mindReading
    case fortuneTelling
    case catastrophizing
    case emotionalReasoning
    case shouldStatements
    case labeling
    case personalization
    case comparison

    public var id: String { rawValue }

    public var info: DistortionInfo { DistortionCatalog.info[self]! }
}

public struct DistortionInfo: Sendable {
    public let name: String
    public let summary: String
    public let example: String
    public let question: String
    public let reframeTip: String
    /// A verified affirmation that speaks to this pattern.
    public let affirmationID: String
    /// First-person balanced-thought templates.
    public let reframes: [String]
}

/// A thinking pattern found in someone's words, with the phrase that suggested it.
public struct DetectedDistortion: Codable, Hashable, Sendable, Identifiable {
    public let distortion: CognitiveDistortion
    /// The words from the person's thought that suggest this pattern.
    public let evidence: String
    /// Optional AI-written explanation tailored to the thought.
    public let explanation: String?

    public var id: String { distortion.rawValue }

    public init(distortion: CognitiveDistortion, evidence: String, explanation: String? = nil) {
        self.distortion = distortion
        self.evidence = evidence
        self.explanation = explanation
    }
}

public enum DistortionCatalog {
    public static let info: [CognitiveDistortion: DistortionInfo] = [
        .allOrNothing: DistortionInfo(
            name: "All-or-Nothing Thinking",
            summary: "Seeing things in black-and-white categories: if it isn't perfect, it's a total failure.",
            example: "“I stumbled over one slide, so the whole presentation was a disaster.”",
            question: "Is there a middle ground here — something that went partly well?",
            reframeTip: "Look for the shades of gray: “Some of it went well, and I can improve the rest.”",
            affirmationID: "purpose-philippians-1-6",
            reframes: [
                "This doesn't have to be all good or all bad. Part of it was hard, part of it went okay, and I can learn from both.",
                "Not being perfect isn't the same as failing. Progress counts, even when it's partial.",
            ]),
        .overgeneralization: DistortionInfo(
            name: "Overgeneralization",
            summary: "Treating one event as a never-ending pattern, often with words like always, never, everyone, or nothing.",
            example: "“I didn't get the job. I'll never find work.”",
            question: "Is it really always or never? Can you think of even one exception?",
            reframeTip: "Swap “always” and “never” for specific, accurate words: “This time, it didn't work out.”",
            affirmationID: "renewal-lamentations-3-22-23",
            reframes: [
                "This was one painful experience, not a pattern that defines everything. It hasn't always been this way, and it won't always be.",
                "“Always” and “never” aren't the full truth. This time was hard; other times have gone differently.",
            ]),
        .mentalFilter: DistortionInfo(
            name: "Mental Filter",
            summary: "Dwelling on one negative detail until it colors everything else.",
            example: "“One person frowned during my talk, so the whole day was ruined.”",
            question: "What else happened that your mind might be filtering out?",
            reframeTip: "Widen the lens: name what went well alongside what went wrong.",
            affirmationID: "renewal-philippians-4-8",
            reframes: [
                "The painful part is real, but it isn't the whole picture. Other things happened that are also true.",
                "I can acknowledge what went wrong without letting it erase everything that went right.",
            ]),
        .discountingPositive: DistortionInfo(
            name: "Discounting the Positive",
            summary: "Insisting that good things don't count: “That was just luck” or “They were only being nice.”",
            example: "“I passed, but it doesn't count — the test was easy.”",
            question: "If a friend achieved this, would you tell them it doesn't count?",
            reframeTip: "Let good things land: “I did that, and I'm thankful for it.”",
            affirmationID: "gratitude-psalm-103-2",
            reframes: [
                "Good things count, too. I can let what went well be real instead of explaining it away.",
                "If a friend did this, I'd tell them it mattered. I can give myself the same credit.",
            ]),
        .mindReading: DistortionInfo(
            name: "Mind Reading",
            summary: "Assuming you know what others are thinking — usually something negative about you.",
            example: "“They didn't text back. They must think I'm annoying.”",
            question: "What evidence do you actually have? What else could explain it?",
            reframeTip: "Hold your guess loosely, or ask: “I wonder what they meant.”",
            affirmationID: "identity-1john-3-1",
            reframes: [
                "I can't actually see inside other people's minds. Without more information, there are other explanations for what happened.",
                "My guess about what they think is just a guess. I can hold it loosely, or simply ask.",
            ]),
        .fortuneTelling: DistortionInfo(
            name: "Fortune Telling",
            summary: "Predicting that things will turn out badly, as if the future were already decided.",
            example: "“This interview is going to go terribly.”",
            question: "What is the most likely outcome — not the worst? How accurate have past predictions been?",
            reframeTip: "Focus on today's next step and entrust tomorrow to God.",
            affirmationID: "peace-matthew-6-34",
            reframes: [
                "I don't know how this will turn out. I can take the next small step today and trust God with tomorrow.",
                "My prediction isn't a fact. The future holds more possibilities than my fear can see right now.",
            ]),
        .catastrophizing: DistortionInfo(
            name: "Catastrophizing",
            summary: "Blowing things up into the worst possible outcome, or telling yourself you can't stand it.",
            example: "“If I make one mistake, my life is over.”",
            question: "If the worst did happen, how would you cope, and who would help? What's most likely?",
            reframeTip: "Name it accurately: “This is hard and painful, and I can get through it with help.”",
            affirmationID: "strength-2corinthians-4-8-9",
            reframes: [
                "This is hard, and it is not the end. I've gotten through hard things before, and I'm not facing this alone.",
                "Even if the worst happened, I would find a way through with God's help and the people around me — and the worst isn't the most likely outcome.",
            ]),
        .emotionalReasoning: DistortionInfo(
            name: "Emotional Reasoning",
            summary: "Believing something is true because it feels true: “I feel worthless, so I must be.”",
            example: "“I feel like a failure, so I must be one.”",
            question: "What would you conclude if you felt calmer? What do the facts say?",
            reframeTip: "Feelings are real messengers, not reliable judges: “I feel like a failure, and I am not a failure.”",
            affirmationID: "hope-psalm-42-5",
            reframes: [
                "My feelings are real, but they aren't proof. I can feel this way and still look at what's actually true.",
                "Feeling it doesn't make it a fact. Feelings are messengers, not judges.",
            ]),
        .shouldStatements: DistortionInfo(
            name: "“Should” Statements",
            summary: "Rigid rules about how you or others must be, which breed guilt and frustration.",
            example: "“I should be over this by now.”",
            question: "Who made this rule? Would “I'd like to” be more accurate and kinder?",
            reframeTip: "Swap “should” for “I'd like to”: “I'd like to handle this better, and I'm learning.”",
            affirmationID: "rest-matthew-11-29",
            reframes: [
                "Instead of “I should,” I can say “I'd like to.” I'm allowed to be a person in progress.",
                "Rigid rules make grace hard to receive. I can hold good hopes for myself with gentleness.",
            ]),
        .labeling: DistortionInfo(
            name: "Labeling",
            summary: "Attaching a harsh, global label to yourself or others: “I'm a failure,” “I'm an idiot.”",
            example: "“I forgot her birthday. I'm a terrible friend.”",
            question: "Would you call a friend that? What's a more specific, fair description?",
            reframeTip: "Describe the behavior, not your identity: “I made a mistake” instead of “I am a mistake.”",
            affirmationID: "identity-ephesians-2-10",
            reframes: [
                "I made a mistake; I am not a mistake. One moment doesn't get to define who I am.",
                "A harsh label isn't a fair description of a whole person — including me.",
            ]),
        .personalization: DistortionInfo(
            name: "Personalization & Blame",
            summary: "Taking responsibility for things outside your control — or putting all the blame on someone else.",
            example: "“My friend is upset, so it must be my fault.”",
            question: "What part was actually yours? What other factors were involved?",
            reframeTip: "Own your part with grace and release what isn't yours to carry.",
            affirmationID: "rest-psalm-55-22",
            reframes: [
                "I can own my part without carrying what was never mine to carry. Many things contributed to this.",
                "Taking responsibility doesn't mean taking all the blame. I can learn, make amends where needed, and release the rest.",
            ]),
        .comparison: DistortionInfo(
            name: "Unfair Comparison",
            summary: "Measuring yourself against other people's highlight reels and coming up short.",
            example: "“Everyone my age is married with a great career. I'm so behind.”",
            question: "Are you comparing your inside to someone else's outside? What progress have you made?",
            reframeTip: "Compare yourself with who you were, not with someone else.",
            affirmationID: "identity-psalm-139-14",
            reframes: [
                "I'm comparing my inside to someone else's outside. My path is my own, and growth looks different for everyone.",
                "Someone else's progress doesn't cancel mine. I can measure my growth by who I was, not by who they are.",
            ]),
    ]
}

/// Keyword-and-pattern detector for cognitive distortions. Deterministic and fully offline.
public enum DistortionDetector {
    /// Minimum total weight for a pattern to be reported.
    public static let threshold = 2

    private static let me = #"(?:i'm|im|i am)"#
    private static let harshLabels = #"(?:failure|loser|idiot|moron|stupid|worthless|useless|pathetic|disappointment|mess|burden|joke|fraud|nobody|waste of space|waste|terrible person|bad person|horrible person|awful person|terrible friend|bad friend|terrible mother|terrible father|bad mom|bad dad|bad parent|terrible parent|monster|weak|weakling|coward|ugly|unlovable|disgusting|hopeless case|screw-?up|failure as a \w+)"#

    private static let labelingSelfPattern: String = {
        let qualifiers = #" (a |an |such a |such an |so |just a |just an |nothing but a |the biggest |a total |a complete |an absolute |a huge |the )?"#
        return #"\b"# + me + qualifiers + harshLabels + #"\b"#
    }()

    static let patterns: [CognitiveDistortion: [WeightedPattern]] = [
        .allOrNothing: [
            WeightedPattern(#"\b(completely|totally|entirely|utterly|absolutely|100 ?%) (ruined|useless|worthless|hopeless|wrong|failed|stupid|broken|pointless|done|over)\b"#, weight: 3),
            WeightedPattern(#"\b(perfect|perfectly|flawless|flawlessly)\b"#, weight: 2),
            WeightedPattern(#"\b(a |an )?(complete|total|utter) (failure|disaster|mess|waste|loser|idiot|fool)\b"#, weight: 3),
            WeightedPattern(#"\bruined (everything|it all)\b"#, weight: 3),
            WeightedPattern(#"\ball or nothing\b"#, weight: 3),
            WeightedPattern(#"\b(nothing|everything) (is|was) (ruined|wrong|bad|terrible|pointless)\b"#, weight: 2),
            WeightedPattern(#"\bif (it's|its|it is|i'm|im|i am) not perfect\b"#, weight: 3),
            WeightedPattern(#"\b(either|it's either) .{1,40} or (nothing|failure|i'm a failure)\b"#, weight: 2),
        ],
        .overgeneralization: [
            WeightedPattern(#"\b(always|never|constantly|forever)\b"#, weight: 2),
            WeightedPattern(#"\b(every ?time|every single time|all the time)\b"#, weight: 2),
            WeightedPattern(#"\b(everyone|everybody|no ?one|nobody|nothing|everything)\b"#, weight: 1),
            WeightedPattern(#"\bnothing ever\b|\bnever ever\b|\bthis always happens\b"#, weight: 2),
        ],
        .mentalFilter: [
            WeightedPattern(#"\b(all i can|the only thing i can|i can't stop|i cant stop|can't stop|cant stop) (think|thinking|see|remember|focus)( about| on)?\b"#, weight: 3),
            WeightedPattern(#"\b(only|just) (see|notice|remember|think about|focus on) (the )?(bad|negative|mistakes?|failures?|criticism|flaws?)\b"#, weight: 3),
            WeightedPattern(#"\bthe one (thing|mistake|comment|person)\b"#, weight: 2),
            WeightedPattern(#"\bruined (the whole|my whole|the entire|my entire) (day|night|week|weekend|evening|event|presentation|thing|trip|date)\b"#, weight: 3),
            WeightedPattern(#"\bkeep (replaying|thinking about|going over)\b"#, weight: 2),
        ],
        .discountingPositive: [
            WeightedPattern(#"\b(doesn't|doesnt|don't|dont|didn't|didnt|does not|do not) (really )?(count|matter|mean anything)\b"#, weight: 3),
            WeightedPattern(#"\b(just|only|pure|dumb|sheer) luck\b|\bfluke\b"#, weight: 3),
            WeightedPattern(#"\b(they|he|she|people|everyone) (were|was|are|is|'re|'s) (just|only) (being )?(nice|polite|kind|pitying me)\b"#, weight: 3),
            WeightedPattern(#"\banyone (could|can) (have )?(do|done|did) (it|that)\b"#, weight: 3),
            WeightedPattern(#"\bit was (nothing|no big deal)\b"#, weight: 2),
            WeightedPattern(#"\byes,? but\b"#, weight: 2),
        ],
        .mindReading: [
            WeightedPattern(#"\b(they|he|she|everyone|everybody|people|others|my \w+) (must|probably|definitely|all|secretly|clearly)? ?(think|thinks|thought|believe|believes|see|sees|know|knows) (i'm|im|i am|that i'm|that i am|i was|of me|me as)\b"#, weight: 3),
            WeightedPattern(#"\b(they|he|she|everyone|everybody|people|my \w+) (all )?(hate|hates|despise|despises|judge|judges|are judging|is judging|are laughing at|is laughing at|are annoyed with|is annoyed with|are disappointed in|is disappointed in|are tired of|is tired of|are sick of|is sick of) me\b"#, weight: 3),
            WeightedPattern(#"\b(no ?one|nobody)( [a-z']+){0,3} (likes|loves|cares about|wants|respects) me\b"#, weight: 3),
            WeightedPattern(#"\b(i can tell|i just know) (that )?(they|he|she|everyone|people)\b"#, weight: 3),
            WeightedPattern(#"\b(they're|theyre|they are) (all )?(talking|laughing|gossiping) about me\b"#, weight: 3),
        ],
        .fortuneTelling: [
            WeightedPattern(#"\b(will|'ll|going to|gonna) (never|always|fail|mess up|screw up|ruin|lose|reject|leave|hate|be alone|end badly|go wrong|be a disaster|be terrible|not work|not get better)\b"#, weight: 3),
            WeightedPattern(#"\b(i'll|ill|i will) never\b|\bnever going to\b|\bnot going to (work|get better|change|happen)\b"#, weight: 3),
            WeightedPattern(#"\bnothing (will|is going to) (ever )?(change|get better|work|improve)\b"#, weight: 3),
            WeightedPattern(#"\bwhat if\b"#, weight: 2),
            WeightedPattern(#"\b(it's|its|it is|this is) (going to|gonna) be (a disaster|terrible|awful|horrible|bad|a mess)\b"#, weight: 3),
            WeightedPattern(#"\b(i know|i'm sure|im sure|i just know) (it|i|they|this|he|she) ('ll|will|is going to|am going to|are going to|won't)\b"#, weight: 2),
            WeightedPattern(#"\b(i'll|ill|i will) (always|forever) be\b"#, weight: 3),
        ],
        .catastrophizing: [
            WeightedPattern(#"\b(disaster|disastrous|catastrophe|catastrophic|nightmare|end of the world|horrific|unbearable|devastating|devastated)\b"#, weight: 2),
            WeightedPattern(#"\b(worst)\b"#, weight: 2),
            WeightedPattern(#"\b(can't|cant|cannot) (handle|take|stand|bear|cope with|deal with|survive) (it|this|that|any more|anymore)\b"#, weight: 3),
            WeightedPattern(#"\b(my )?life is (over|ruined)\b"#, weight: 3),
            WeightedPattern(#"\b(everything|it's all|its all|it is all) (is )?(falling apart|ruined|over|collapsing)\b"#, weight: 3),
            WeightedPattern(#"\b(terrible|awful|dreadful|horrible)\b"#, weight: 1),
        ],
        .emotionalReasoning: [
            WeightedPattern(#"\bi feel (like )?(a |an |so |such a |completely |totally |like a |like such a )?(failure|stupid|worthless|useless|unlovable|guilty|ugly|hopeless|helpless|burden|fraud|idiot|loser|inadequate|broken|disgusting|bad person|terrible person|not good enough)\b"#, weight: 3),
            WeightedPattern(#"\bi feel (it|that) .{0,40}(so|therefore) (it|i) (must|am|is)\b"#, weight: 3),
            WeightedPattern(#"\bbecause i feel\b"#, weight: 2),
            WeightedPattern(#"\bfeels? (so )?(true|real),? so\b"#, weight: 2),
            WeightedPattern(#"\bi feel like (no ?one|nobody|everyone|nothing|everything|i'll|i will|it will|it's going to|i'm going to)\b"#, weight: 2),
            WeightedPattern(#"\bmy (gut|feelings?) (tells?|says?) (me )?\b"#, weight: 2),
        ],
        .shouldStatements: [
            WeightedPattern(#"\b(should|shouldn't|shouldnt|should not|should have|should've|shouldve)\b"#, weight: 2),
            WeightedPattern(#"\b(must|mustn't|must not|ought to|ought not|supposed to)\b"#, weight: 2),
            WeightedPattern(#"\b(have to|has to|had to|need to) be (perfect|better|stronger|more|over it|fine|happy|strong)\b"#, weight: 2),
            WeightedPattern(#"\b(have to|has to|had to)\b"#, weight: 1),
        ],
        .labeling: [
            WeightedPattern(labelingSelfPattern, weight: 3),
            WeightedPattern(#"\b(what a|such an?) (idiot|loser|failure|fool|mess)\b"#, weight: 2),
            WeightedPattern(#"\b(he's|she's|hes|shes|they're|theyre|he is|she is|they are) (an? |such an? |a total |a complete )?(idiot|jerk|loser|monster|selfish|narcissist|failure)\b"#, weight: 2),
            WeightedPattern(#"\bi('m| am) (nothing|no one|nobody)\b"#, weight: 3),
        ],
        .personalization: [
            WeightedPattern(#"\b(it's|its|it is|it was|it's all|its all|it was all|all) my fault\b"#, weight: 3),
            WeightedPattern(#"\bmy fault\b"#, weight: 2),
            WeightedPattern(#"\bbecause of me\b"#, weight: 3),
            WeightedPattern(#"\bi (ruined|caused|destroyed|wrecked) (it|everything|this|their|his|her|our|the)\b"#, weight: 2),
            WeightedPattern(#"\b(i'm|im|i am) (to blame|responsible for (their|his|her|everyone's|everyones))\b"#, weight: 3),
            WeightedPattern(#"\bblame myself\b"#, weight: 3),
            WeightedPattern(#"\bi should have (known|seen|stopped|prevented|done more|been there|noticed|saved)\b"#, weight: 3),
            WeightedPattern(#"\bif only i (had|hadn't|hadnt|would have|could have|did|didn't)\b"#, weight: 2),
            WeightedPattern(#"\b(it's|its|it is|it was) (all )?(their|his|her|your) fault\b"#, weight: 2),
        ],
        .comparison: [
            WeightedPattern(#"\b(everyone|everybody|all my friends|other people|others|my friends|my siblings|people my age) (else )?(is|are|has|have|gets|get|seems?|seem|looks?) (so )?(better|happier|smarter|prettier|richer|further|ahead|married|successful|more \w+|doing better)\b"#, weight: 3),
            WeightedPattern(#"\b(better|smarter|prettier|happier|richer|thinner|more successful|more talented|more popular) than me\b"#, weight: 3),
            WeightedPattern(#"\b(compared to|compared with|comparing myself|compare myself)\b"#, weight: 3),
            WeightedPattern(#"\b(behind|left behind) (everyone|everybody|my friends|my peers|others|people my age)\b"#, weight: 3),
            WeightedPattern(#"\b(jealous|envious) of\b"#, weight: 2),
            WeightedPattern(#"\bwhy can't i be (like|more like)\b|\bwhy cant i be (like|more like)\b"#, weight: 3),
        ],
    ]

    /// Detects up to `limit` thinking patterns, strongest first.
    public static func detect(in text: String, limit: Int = 3) -> [DetectedDistortion] {
        let normalized = TextTools.normalize(text)
        guard !normalized.isEmpty else { return [] }
        var scored: [(CognitiveDistortion, Int, String)] = []
        for distortion in CognitiveDistortion.allCases {
            guard let rules = patterns[distortion] else { continue }
            var total = 0
            var evidence: String?
            var bestWeight = 0
            for rule in rules {
                if let match = rule.firstMatch(in: normalized) {
                    total += rule.weight
                    if rule.weight > bestWeight {
                        bestWeight = rule.weight
                        evidence = match
                    }
                }
            }
            if total >= threshold, let evidence {
                scored.append((distortion, total, evidence.trimmingCharacters(in: .whitespaces)))
            }
        }
        let order = CognitiveDistortion.allCases
        scored.sort { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return order.firstIndex(of: lhs.0)! < order.firstIndex(of: rhs.0)!
        }
        return scored.prefix(max(0, limit)).map { DetectedDistortion(distortion: $0.0, evidence: $0.2) }
    }
}
