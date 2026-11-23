import Foundation

public enum ReframeSource: String, Codable, Sendable {
    case offline, onDevice, claude

    public var title: String {
        switch self {
        case .offline: return "Offline guide"
        case .onDevice: return "Apple Intelligence (on-device)"
        case .claude: return "Claude"
        }
    }
}

/// The healthier perspective offered for one thought.
public struct ReframeResult: Codable, Hashable, Sendable {
    public var source: ReframeSource
    /// Which model produced the result, when AI was used (e.g. "claude-fable-5-2").
    public var modelID: String?
    public var crisisLevel: CrisisLevel
    public var validation: String
    public var distortions: [DetectedDistortion]
    public var questions: [String]
    public var balancedThought: String
    /// A verified affirmation from the content library.
    public var affirmationID: String
    public var personalAffirmation: String
    public var nextStep: String
    public var suggestedPracticeID: String?
    public var concerns: [Concern]
    /// A short note shown to the person, e.g. why AI wasn't used.
    public var notice: String?
    /// Technical detail of an AI failure, for diagnostics (not shown to people in normal use).
    public var errorDetail: String?

    public init(source: ReframeSource, modelID: String? = nil, crisisLevel: CrisisLevel, validation: String,
                distortions: [DetectedDistortion], questions: [String], balancedThought: String,
                affirmationID: String, personalAffirmation: String, nextStep: String,
                suggestedPracticeID: String?, concerns: [Concern], notice: String? = nil) {
        self.source = source
        self.modelID = modelID
        self.crisisLevel = crisisLevel
        self.validation = validation
        self.distortions = distortions
        self.questions = questions
        self.balancedThought = balancedThought
        self.affirmationID = affirmationID
        self.personalAffirmation = personalAffirmation
        self.nextStep = nextStep
        self.suggestedPracticeID = suggestedPracticeID
        self.concerns = concerns
        self.notice = notice
    }
}

/// Fully offline cognitive-reframing engine: CBT thinking patterns + Christ-centered truth.
public struct ReframeEngine: Sendable {
    public let library: ContentLibrary

    public init(library: ContentLibrary) {
        self.library = library
    }

    /// Hints passed to AI models.
    public struct Analysis: Sendable {
        public let crisis: CrisisAssessment
        public let distortions: [DetectedDistortion]
        public let concerns: [Concern]
    }

    public func analyze(_ thought: String) -> Analysis {
        Analysis(crisis: CrisisDetector.assess(thought),
                 distortions: DistortionDetector.detect(in: thought),
                 concerns: ConcernClassifier.classify(thought))
    }

    public func reframe(_ thought: String) -> ReframeResult {
        reframe(thought, analysis: analyze(thought))
    }

    public func reframe(_ thought: String, analysis: Analysis) -> ReframeResult {
        let seed = TextTools.normalize(thought)

        if analysis.crisis.level == .urgent {
            return crisisResult(concerns: analysis.concerns)
        }

        let primaryConcern = analysis.concerns.first
        let guidance = primaryConcern?.guidance ?? ConcernCatalog.general
        let primaryDistortion = analysis.distortions.first?.distortion

        // Validation
        let validation = TextTools.pick(guidance.validations, seed: seed, salt: "validation")
            ?? ConcernCatalog.general.validations[0]

        // Balanced thought: a reframe for the main thinking pattern plus a truth for the concern.
        var balanced: String
        if let primaryDistortion {
            let reframes = primaryDistortion.info.reframes
            balanced = TextTools.pick(reframes, seed: seed, salt: "reframe") ?? reframes[0]
            balanced += " " + guidance.truth
        } else {
            balanced = guidance.truth
            if primaryConcern == nil {
                balanced = "I'm noticing a painful thought, and I don't have to accept it as the whole truth. " + guidance.truth
            }
        }

        // Questions: one per thinking pattern, then the concern question, then a classic CBT question.
        var questions: [String] = []
        for detected in analysis.distortions {
            let question = detected.distortion.info.question
            if !questions.contains(question) { questions.append(question) }
        }
        if !questions.contains(guidance.question) { questions.append(guidance.question) }
        let friendQuestion = "What would you say to a close friend who had this thought?"
        if !questions.contains(friendQuestion) { questions.append(friendQuestion) }
        questions = Array(questions.prefix(3))

        // Scripture: from the concern's themes, otherwise from the thinking pattern, otherwise renewal.
        let affirmation = chooseAffirmation(concern: primaryConcern, distortion: primaryDistortion, seed: seed)

        return ReframeResult(
            source: .offline,
            crisisLevel: analysis.crisis.level,
            validation: validation,
            distortions: analysis.distortions,
            questions: questions,
            balancedThought: balanced,
            affirmationID: affirmation.id,
            personalAffirmation: affirmation.affirmation,
            nextStep: guidance.nextStep,
            suggestedPracticeID: library.practice(id: guidance.practiceID) != nil ? guidance.practiceID : nil,
            concerns: analysis.concerns)
    }

    /// Picks a verse: hand-picked verses for the concern (plus the verse linked to the main thinking pattern),
    /// the pattern's verse when no concern is clear, or a renewal verse otherwise.
    func chooseAffirmation(concern: Concern?, distortion: CognitiveDistortion?, seed: String) -> Affirmation {
        if concern == nil, let distortion, let linked = library.affirmation(id: distortion.info.affirmationID) {
            return linked
        }
        let guidance = concern?.guidance ?? ConcernCatalog.general
        var ids = guidance.affirmationIDs
        if let distortion, !ids.contains(distortion.info.affirmationID) {
            ids.append(distortion.info.affirmationID)
        }
        let candidates = ids.compactMap { library.affirmation(id: $0) }
        return TextTools.pick(candidates, seed: seed, salt: "scripture")
            ?? TextTools.pick(library.affirmations(for: .renewal), seed: seed, salt: "scripture")
            ?? library.affirmations[0]
    }

    public static let crisisAffirmationID = "healing-psalm-34-18"

    func crisisResult(concerns: [Concern]) -> ReframeResult {
        let affirmation = library.affirmation(id: Self.crisisAffirmationID) ?? library.affirmations[0]
        return ReframeResult(
            source: .offline,
            crisisLevel: .urgent,
            validation: "I'm really glad you told me. What you're carrying sounds incredibly painful, and you deserve support right now — not tomorrow, and not alone.",
            distortions: [],
            questions: [],
            balancedThought: "Right now, the most important thing is your safety. You don't have to face this by yourself. Reaching out for help is a strong and wise thing to do.",
            affirmationID: affirmation.id,
            personalAffirmation: affirmation.affirmation,
            nextStep: "Please reach out now: call or text a crisis line or your local emergency number, and if you can, tell someone near you how you're feeling.",
            suggestedPracticeID: "grounding-54321",
            concerns: concerns)
    }
}
