import Foundation

/// What a painful thought is about. Used to choose comfort, Scripture, and a next step.
public enum Concern: String, Codable, CaseIterable, Sendable, Identifiable {
    case worth, anxiety, loneliness, guilt, failure, grief, hopelessness
    case anger, overwhelm, health, comparison, faith, sleep

    public var id: String { rawValue }

    public var guidance: ConcernGuidance { ConcernCatalog.guidance[self]! }
}

public struct ConcernGuidance: Sendable {
    public let title: String
    public let validations: [String]
    /// First-person truth statement appended to the balanced thought.
    public let truth: String
    public let question: String
    public let nextStep: String
    public let practiceID: String
    public let themes: [Theme]
    public let need: WellbeingNeed
    /// Hand-picked affirmations that speak most directly to this concern, best first.
    public let affirmationIDs: [String]
}

public enum ConcernCatalog {
    public static let general = ConcernGuidance(
        title: "A hard thought",
        validations: [
            "Thank you for putting this into words. Naming a hard thought is a brave first step, and you don't have to sort it out alone.",
            "That sounds heavy. It makes sense to want a different way of seeing it.",
        ],
        truth: "This thought is one way of seeing things, but it isn't the only way — and it doesn't get the last word.",
        question: "What evidence supports this thought, and what evidence doesn't?",
        nextStep: "Take two minutes to breathe slowly, then write a kinder, more balanced version of this thought in your own words.",
        practiceID: "breath-prayer",
        themes: [.renewal, .peace],
        need: .rumination,
        affirmationIDs: ["renewal-romans-12-2", "renewal-philippians-4-8", "renewal-2corinthians-10-5", "peace-isaiah-26-3"])

    public static let guidance: [Concern: ConcernGuidance] = [
        .worth: ConcernGuidance(
            title: "Self-worth",
            validations: [
                "It hurts to feel this way about yourself. Thoughts like this can feel heavy and very convincing.",
                "That sounds painful. When we feel like we're not enough, it can color everything.",
            ],
            truth: "My worth was settled by God before I accomplished anything, and it isn't up for a vote today.",
            question: "What would someone who truly loves you say about who you are?",
            nextStep: "Write down three things God and the people who love you would say are true about you.",
            practiceID: "self-compassion-break",
            themes: [.identity, .love],
            need: .selfCriticism,
            affirmationIDs: ["identity-psalm-139-14", "identity-ephesians-2-10", "identity-1john-3-1", "love-zephaniah-3-17", "love-romans-8-38-39", "identity-isaiah-43-1"]),
        .anxiety: ConcernGuidance(
            title: "Anxiety and worry",
            validations: [
                "That sounds really stressful. Anxiety often shows up around the things that matter most to us.",
                "It makes sense that your mind is on high alert. Worry is exhausting, and you don't have to carry it alone.",
            ],
            truth: "I don't have to carry tomorrow today. God is with me in this moment, and I can take the next small step.",
            question: "What is within your control right now, and what can you hand over to God?",
            nextStep: "Try two minutes of Breath Prayer, then write down one small thing you can control today.",
            practiceID: "breath-prayer",
            themes: [.peace, .courage],
            need: .anxiety,
            affirmationIDs: ["peace-philippians-4-6", "peace-1peter-5-7", "peace-matthew-6-34", "courage-isaiah-41-10", "peace-john-14-27", "comfort-psalm-94-19", "rest-psalm-46-10"]),
        .loneliness: ConcernGuidance(
            title: "Loneliness",
            validations: [
                "Feeling alone is one of the hardest feelings there is. Thank you for saying it out loud.",
                "That sounds lonely and painful. Longing for connection is part of how God made you.",
            ],
            truth: "Even when I feel alone, I am not forgotten. God is near, and connection can grow one small step at a time.",
            question: "Is there one person you could reach out to, even with a short message?",
            nextStep: "Send a short message to one person you trust — even just “thinking of you.”",
            practiceID: "reach-out",
            themes: [.connection, .love, .comfort],
            need: .loneliness,
            affirmationIDs: ["healing-psalm-34-18", "courage-deuteronomy-31-8", "connection-john-15-15", "love-romans-8-38-39", "connection-ecclesiastes-4-9-10"]),
        .guilt: ConcernGuidance(
            title: "Guilt and shame",
            validations: [
                "Guilt and shame can feel crushing. The fact that you care about doing right says something good about your heart.",
                "It's painful to replay something you regret. You don't have to hide it.",
            ],
            truth: "In Christ there is forgiveness, not condemnation. I can own what I did, make amends where I can, and receive grace.",
            question: "If you've brought this to God, what would it look like to accept His forgiveness?",
            nextStep: "Name what happened honestly to God, and if it's wise, take one step toward making it right.",
            practiceID: "self-compassion-break",
            themes: [.forgiveness, .identity],
            need: .selfCriticism,
            affirmationIDs: ["forgiveness-romans-8-1", "forgiveness-1john-1-9", "forgiveness-psalm-103-12", "renewal-psalm-51-10", "renewal-lamentations-3-22-23"]),
        .failure: ConcernGuidance(
            title: "Setbacks and failure",
            validations: [
                "Setbacks hurt, especially when you've worked hard. It's okay to be disappointed.",
                "That sounds discouraging. Falling short of what you hoped can shake your confidence.",
            ],
            truth: "A setback is an event, not an identity. God is still at work in me, and I can learn and try again.",
            question: "What would you tell a friend who had the same setback?",
            nextStep: "Write down one thing this taught you and one small next step you can take this week.",
            practiceID: "one-small-step",
            themes: [.renewal, .strength, .purpose],
            need: .selfCriticism,
            affirmationIDs: ["purpose-philippians-1-6", "strength-2corinthians-12-9", "renewal-lamentations-3-22-23", "identity-2corinthians-5-17", "strength-psalm-73-26"]),
        .grief: ConcernGuidance(
            title: "Grief and loss",
            validations: [
                "I'm so sorry. Grief is a form of love, and it deserves room.",
                "Loss is heavy. There's no right way or timeline to grieve.",
            ],
            truth: "My grief is not a lack of faith. Jesus wept too, and God holds my tears.",
            question: "What do you need right now: to remember, to rest, or to be with someone?",
            nextStep: "Give yourself permission to grieve today: write a short letter, look at a photo, or call someone who understands.",
            practiceID: "lament-writing",
            themes: [.comfort, .hope],
            need: .grief,
            affirmationIDs: ["comfort-matthew-5-4", "comfort-john-11-35", "comfort-psalm-56-8", "healing-psalm-147-3", "joy-psalm-30-5", "healing-psalm-34-18"]),
        .hopelessness: ConcernGuidance(
            title: "Hopelessness",
            validations: [
                "It sounds like you're carrying a lot of heaviness right now. I'm really glad you put it into words.",
                "When everything feels dark, it's hard to imagine it changing. That feeling is real — and it isn't the whole story.",
            ],
            truth: "Hopeless feelings are real, but they are not prophecies. Small steps, support, and God's faithfulness can bring light back over time.",
            question: "What is one small thing that has helped, even a little, in the past?",
            nextStep: "Do one small, kind thing for your body — a glass of water, a short walk, or rest — and tell someone how you're doing.",
            practiceID: "one-small-step",
            themes: [.hope, .healing, .renewal],
            need: .lowMood,
            affirmationIDs: ["hope-psalm-42-5", "hope-lamentations-3-21", "healing-isaiah-42-3", "hope-jeremiah-29-11", "hope-romans-15-13", "strength-isaiah-40-29"]),
        .anger: ConcernGuidance(
            title: "Anger and hurt",
            validations: [
                "It sounds like you were really hurt. Anger often protects something that matters to us.",
                "That sounds frustrating and unfair. Your feelings make sense.",
            ],
            truth: "I can be angry without letting anger rule me. I can name the hurt, set wise boundaries, and leave final justice to God.",
            question: "What need or value is your anger trying to protect?",
            nextStep: "Take five slow breaths before responding, then write down what you actually need.",
            practiceID: "cyclic-sighing",
            themes: [.peace, .forgiveness],
            need: .anger,
            affirmationIDs: ["peace-colossians-3-15", "forgiveness-ephesians-4-32", "peace-john-14-27", "rest-psalm-46-10"]),
        .overwhelm: ConcernGuidance(
            title: "Overwhelm and stress",
            validations: [
                "That's a lot to carry. No wonder you feel stretched thin.",
                "It sounds like everything is piling up at once. Feeling overwhelmed is a sign you need care, not that you're failing.",
            ],
            truth: "I don't have to do everything at once. I can take the next small step and rest in the God who carries what I can't.",
            question: "What is the one most important thing for today, and what can wait?",
            nextStep: "List everything on your mind, circle just one thing to do next, and set the rest aside for now.",
            practiceID: "one-small-step",
            themes: [.rest, .strength, .peace],
            need: .overwhelm,
            affirmationIDs: ["rest-matthew-11-28", "rest-psalm-55-22", "strength-isaiah-40-29", "rest-psalm-46-10", "strength-2corinthians-4-8-9"]),
        .health: ConcernGuidance(
            title: "Health and the body",
            validations: [
                "Living with pain or health worries is exhausting, in body and in heart.",
                "That sounds really hard. Health struggles can affect everything else.",
            ],
            truth: "My body's struggles don't make me less loved or less valuable. I can care for myself gently and ask for help.",
            question: "What is one gentle way you could care for your body today?",
            nextStep: "Do one small thing for your health today — rest, drink water, stretch gently, or call your doctor.",
            practiceID: "breath-prayer",
            themes: [.healing, .strength],
            need: .lowEnergy,
            affirmationIDs: ["healing-3john-1-2", "healing-exodus-15-26", "strength-psalm-73-26", "strength-2corinthians-12-9", "healing-mark-5-34"]),
        .comparison: ConcernGuidance(
            title: "Comparison",
            validations: [
                "It's painful to feel like you're behind. Comparison can steal joy quickly.",
                "That sounds discouraging. Seeing other people's highlights can make our own lives feel small.",
            ],
            truth: "My life isn't a race against anyone else. I can celebrate others and still honor my own path.",
            question: "What progress have you made compared with a year ago?",
            nextStep: "Write down three ways you've grown this year, and thank God for one gift He has given you.",
            practiceID: "use-your-gifts",
            themes: [.identity, .purpose, .gratitude],
            need: .selfCriticism,
            affirmationIDs: ["identity-psalm-139-14", "purpose-romans-12-6", "identity-ephesians-2-10", "purpose-galatians-6-9", "gratitude-colossians-2-7"]),
        .faith: ConcernGuidance(
            title: "Feeling far from God",
            validations: [
                "Feeling far from God can be lonely and confusing. Many faithful people in Scripture felt this way too.",
                "Doubt and dryness are part of many people's journeys with God. Being honest about it is itself an act of faith.",
            ],
            truth: "My feelings about God's distance don't change His nearness. I can bring my honest questions to Him, as the psalmists did.",
            question: "What would you say to God right now if you could be completely honest?",
            nextStep: "Read a psalm of lament, like Psalm 13 or Psalm 42, and write God a short, honest prayer.",
            practiceID: "lament-writing",
            themes: [.love, .comfort, .hope],
            need: .spiritualDryness,
            affirmationIDs: ["hope-psalm-42-5", "love-romans-8-38-39", "healing-psalm-34-18", "love-jeremiah-31-3", "courage-deuteronomy-31-8"]),
        .sleep: ConcernGuidance(
            title: "Sleep",
            validations: [
                "Not sleeping well makes everything feel harder. It makes sense that you're struggling.",
                "Tired minds tend to see things more darkly. Be gentle with yourself.",
            ],
            truth: "Rest is a gift, not a reward. I can hand tonight's worries to God and let my body rest.",
            question: "What could you set down tonight so your mind can rest?",
            nextStep: "Tonight, try the Sleep Wind-Down: dim the lights, put your phone away, and pray Psalm 4:8.",
            practiceID: "sleep-wind-down",
            themes: [.rest, .peace],
            need: .sleep,
            affirmationIDs: ["rest-psalm-4-8", "rest-psalm-127-2", "rest-psalm-23-2", "rest-psalm-62-1"]),
    ]
}

/// Keyword classifier for what a thought is about.
public enum ConcernClassifier {
    static let lexicon: [Concern: [WeightedPattern]] = [
        .worth: [
            WeightedPattern(#"\b(worthless|unlovable|not good enough|not enough|inadequate|fraud|impostor|imposter|disappointment|don't deserve|dont deserve|hate myself|i hate me|ugly|disgusting|no value)\b"#, weight: 2),
            WeightedPattern(#"\b(i'm|im|i am) (so |such a |a |an )?(stupid|useless|a failure|a loser|nothing|a burden|pathetic|an idiot|ugly|fat|unlovable|not worth)\b"#, weight: 2),
            WeightedPattern(#"\b(no ?one|nobody) (loves|cares about|likes|wants) me\b"#, weight: 1),
        ],
        .anxiety: [
            WeightedPattern(#"\b(anxious|anxiety|worried|worry|worrying|scared|afraid|fear|fearful|panic|panicking|nervous|terrified|dread|dreading|overthink|overthinking|on edge|racing thoughts|uneasy)\b"#, weight: 2),
            WeightedPattern(#"\bwhat if\b"#, weight: 1),
            WeightedPattern(#"\b(going to|gonna|will|'ll) (fail|mess up|screw up|lose|go wrong|be a disaster|embarrass myself)\b"#, weight: 3),
        ],
        .loneliness: [
            WeightedPattern(#"\b(alone|lonely|loneliness|isolated|left out|ignored|abandoned|unwanted|rejected|rejection|no friends|no one to talk to|nobody to talk to)\b"#, weight: 2),
            WeightedPattern(#"\b(no ?one|nobody)( [a-z']+){0,3} (cares|understands|listens|calls|texts|likes me|wants me|loves me|invites me|talks to me|wants to be with me)\b"#, weight: 2),
        ],
        .guilt: [
            WeightedPattern(#"\b(guilt|guilty|ashamed|shame|regret|regrets|sinned|sin|sins|unforgivable|condemned|can't forgive myself|cant forgive myself)\b"#, weight: 2),
            WeightedPattern(#"\b(my fault|let (everyone|them|god|him|her|my \w+) down)\b"#, weight: 2),
        ],
        .failure: [
            WeightedPattern(#"\b(fail|failed|failing|failure|mistake|mistakes|messed up|screwed up|mess up|incompetent|lazy|unproductive|not good at|got fired|fired|rejected from)\b"#, weight: 2),
            WeightedPattern(#"\b(exam|test|grade|grades|interview|job|work|boss|deadline|presentation|project|career|school|class)\b"#, weight: 1),
        ],
        .grief: [
            WeightedPattern(#"\b(died|death|passed away|lost my|grief|grieving|grieve|funeral|miscarriage|divorce|breakup|broke up|widow|widowed)\b"#, weight: 2),
            WeightedPattern(#"\b(miss (him|her|them|my \w+)|gone forever)\b"#, weight: 2),
        ],
        .hopelessness: [
            WeightedPattern(#"\b(hopeless|pointless|no point|give up|giving up|empty|numb|depressed|depression|nothing matters|never get better|no future|darkness|can't go on|cant go on)\b"#, weight: 2),
            WeightedPattern(#"\b(stuck|dark|heavy)\b"#, weight: 1),
        ],
        .anger: [
            WeightedPattern(#"\b(angry|anger|furious|mad at|resent|resentment|bitter|betrayed|betrayal|rage|livid|frustrated|annoyed)\b"#, weight: 2),
            WeightedPattern(#"\b(hate (him|her|them|it|my \w+)|so unfair|not fair|can't forgive (him|her|them)|cant forgive (him|her|them))\b"#, weight: 2),
        ],
        .overwhelm: [
            WeightedPattern(#"\b(overwhelmed|overwhelming|stressed|stress|too much|burned out|burnt out|burnout|exhausted|can't keep up|cant keep up|drowning|pressure|so much to do|falling behind|no time)\b"#, weight: 2),
        ],
        .health: [
            WeightedPattern(#"\b(sick|illness|ill|chronic|diagnosis|diagnosed|disease|cancer|hospital|surgery|injury|injured|migraine|pain|my body|health)\b"#, weight: 2),
        ],
        .comparison: [
            WeightedPattern(#"\b(everyone else|better than me|jealous|envy|envious|compared to|compare myself|comparing myself|behind everyone|social media|instagram|their perfect)\b"#, weight: 2),
        ],
        .faith: [
            WeightedPattern(#"\bgod (doesn't|does not|doesnt|hates|is angry|has abandoned|abandoned|forgot|has forgotten|is far|feels far|isn't listening|isnt listening|doesn't care|doesnt care|doesn't love|doesnt love|won't|wont)\b"#, weight: 3),
            WeightedPattern(#"\b(far from god|unanswered|prayers? (aren't|arent|are not|isn't|isnt|go) (answered|heard)|doubt|doubting|faith is (weak|gone)|can't pray|cant pray|where is god|why would god|lost my faith)\b"#, weight: 2),
        ],
        .sleep: [
            WeightedPattern(#"\b(can't sleep|cant sleep|cannot sleep|insomnia|awake all night|no sleep|didn't sleep|didnt sleep|tired all the time|nightmares|sleepless)\b"#, weight: 3),
        ],
    ]

    /// Returns up to `limit` concerns, strongest first.
    public static func classify(_ text: String, limit: Int = 2) -> [Concern] {
        let normalized = TextTools.normalize(text)
        guard !normalized.isEmpty else { return [] }
        var scores: [(Concern, Int)] = []
        for concern in Concern.allCases {
            guard let rules = lexicon[concern] else { continue }
            let score = rules.reduce(0) { $0 + ($1.matches(normalized) ? $1.weight : 0) }
            if score >= 2 { scores.append((concern, score)) }
        }
        let order = Concern.allCases
        scores.sort { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return order.firstIndex(of: lhs.0)! < order.firstIndex(of: rhs.0)!
        }
        return scores.prefix(max(0, limit)).map(\.0)
    }
}
