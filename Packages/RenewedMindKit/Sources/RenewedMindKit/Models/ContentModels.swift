import Foundation

/// The fifteen affirmation themes. Each theme groups Scripture-based affirmations.
public enum Theme: String, Codable, CaseIterable, Sendable, Identifiable {
    case renewal, identity, peace, hope, strength, rest, love, forgiveness
    case joy, courage, healing, comfort, gratitude, purpose, connection

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .renewal: return "Renewal"
        case .identity: return "Identity"
        case .peace: return "Peace"
        case .hope: return "Hope"
        case .strength: return "Strength"
        case .rest: return "Rest"
        case .love: return "Love"
        case .forgiveness: return "Forgiveness"
        case .joy: return "Joy"
        case .courage: return "Courage"
        case .healing: return "Healing"
        case .comfort: return "Comfort"
        case .gratitude: return "Gratitude"
        case .purpose: return "Purpose"
        case .connection: return "Connection"
        }
    }

    /// SF Symbol name used by the app.
    public var symbol: String {
        switch self {
        case .renewal: return "arrow.triangle.2.circlepath"
        case .identity: return "person.crop.circle.badge.checkmark"
        case .peace: return "leaf"
        case .hope: return "sunrise"
        case .strength: return "mountain.2"
        case .rest: return "moon.stars"
        case .love: return "heart"
        case .forgiveness: return "hands.and.sparkles"
        case .joy: return "sun.max"
        case .courage: return "shield.lefthalf.filled"
        case .healing: return "bandage"
        case .comfort: return "hand.raised"
        case .gratitude: return "gift"
        case .purpose: return "lightbulb"
        case .connection: return "person.2"
        }
    }

    public var blurb: String {
        switch self {
        case .renewal: return "Trading distorted thoughts for true ones."
        case .identity: return "Who God says you are."
        case .peace: return "A guarded heart and a settled mind."
        case .hope: return "A cord to hold through long seasons."
        case .strength: return "Strength that meets you in weakness."
        case .rest: return "Permission to stop, breathe, and sleep."
        case .love: return "A love nothing can separate you from."
        case .forgiveness: return "Released, cleansed, and free."
        case .joy: return "Calm delight rooted in grace."
        case .courage: return "Steadied by the God who goes before you."
        case .healing: return "Wounds tended with care."
        case .comfort: return "God comes near in grief and tears."
        case .gratitude: return "Noticing grace in every circumstance."
        case .purpose: return "Gifts, growth, and good work."
        case .connection: return "You were not made to walk alone."
        }
    }
}

public enum OriginalLanguage: String, Codable, Sendable {
    case hebrew, greek

    public var displayName: String {
        switch self {
        case .hebrew: return "Hebrew"
        case .greek: return "Greek"
        }
    }
}

/// A short study of one Hebrew or Greek word in an affirmation's verse.
public struct WordStudy: Codable, Hashable, Sendable {
    /// Strong's Concordance number, e.g. "G3339" or "H7965".
    public let strongs: String
    public let language: OriginalLanguage
    /// Dictionary form in the original script (from Strong's).
    public let lemma: String
    public let transliteration: String
    /// The English word(s) in the Berean Standard Bible verse that translate this word.
    public let english: String
    public let meaning: String
    public let insight: String

    public init(strongs: String, language: OriginalLanguage, lemma: String, transliteration: String,
                english: String, meaning: String, insight: String) {
        self.strongs = strongs
        self.language = language
        self.lemma = lemma
        self.transliteration = transliteration
        self.english = english
        self.meaning = meaning
        self.insight = insight
    }
}

/// A first-person, Christ-centered affirmation anchored in a verse of Scripture.
public struct Affirmation: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let theme: Theme
    public let affirmation: String
    /// e.g. "Romans 12:2" or "Lamentations 3:22–23"
    public let reference: String
    /// Verse text from the Berean Standard Bible (public domain).
    public let verse: String
    public let wordStudy: WordStudy
    public let reflection: String

    public init(id: String, theme: Theme, affirmation: String, reference: String, verse: String,
                wordStudy: WordStudy, reflection: String) {
        self.id = id
        self.theme = theme
        self.affirmation = affirmation
        self.reference = reference
        self.verse = verse
        self.wordStudy = wordStudy
        self.reflection = reflection
    }
}

public enum WellnessDimension: String, Codable, CaseIterable, Sendable, Identifiable {
    case spiritual, emotional, mental, physical, social, purpose

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .spiritual: return "Spiritual"
        case .emotional: return "Emotional"
        case .mental: return "Mind"
        case .physical: return "Body"
        case .social: return "Relationships"
        case .purpose: return "Purpose"
        }
    }

    public var symbol: String {
        switch self {
        case .spiritual: return "sparkles"
        case .emotional: return "heart.text.square"
        case .mental: return "brain.head.profile"
        case .physical: return "figure.walk"
        case .social: return "person.2.fill"
        case .purpose: return "scope"
        }
    }
}

public enum PracticeKind: String, Codable, Sendable {
    case breathing, journal, timer, guided, checklist
}

public enum EvidenceLevel: String, Codable, Sendable, Comparable {
    case emerging, moderate, strong

    public var title: String {
        switch self {
        case .strong: return "Strong evidence"
        case .moderate: return "Moderate evidence"
        case .emerging: return "Emerging evidence"
        }
    }

    private var rank: Int {
        switch self {
        case .emerging: return 0
        case .moderate: return 1
        case .strong: return 2
        }
    }

    public static func < (lhs: EvidenceLevel, rhs: EvidenceLevel) -> Bool { lhs.rank < rhs.rank }
}

/// Needs that a practice can help with. Used by the recommendation engine.
public enum WellbeingNeed: String, Codable, CaseIterable, Sendable {
    case lowMood, anxiety, stress, sleep, loneliness, lowEnergy, anger, grief
    case lowMeaning, spiritualDryness, selfCriticism, rumination, overwhelm

    /// Phrase that completes "Because you mentioned …".
    public var phrase: String {
        switch self {
        case .lowMood: return "feeling low"
        case .anxiety: return "anxiety"
        case .stress: return "stress"
        case .sleep: return "trouble sleeping"
        case .loneliness: return "feeling lonely"
        case .lowEnergy: return "low energy"
        case .anger: return "anger or hurt"
        case .grief: return "grief"
        case .lowMeaning: return "wanting more meaning"
        case .spiritualDryness: return "feeling far from God"
        case .selfCriticism: return "being hard on yourself"
        case .rumination: return "repetitive thoughts"
        case .overwhelm: return "feeling overwhelmed"
        }
    }
}

public struct BreathingPattern: Codable, Hashable, Sendable {
    public let inhale: Double
    /// A second, shorter inhale ("top-up") used by cyclic sighing. Zero when unused.
    public let topUp: Double
    public let holdIn: Double
    public let exhale: Double
    public let holdOut: Double
    public let inhaleCue: String
    public let exhaleCue: String

    public init(inhale: Double, topUp: Double = 0, holdIn: Double = 0, exhale: Double, holdOut: Double = 0,
                inhaleCue: String, exhaleCue: String) {
        self.inhale = inhale
        self.topUp = topUp
        self.holdIn = holdIn
        self.exhale = exhale
        self.holdOut = holdOut
        self.inhaleCue = inhaleCue
        self.exhaleCue = exhaleCue
    }

    public var cycleSeconds: Double { inhale + topUp + holdIn + exhale + holdOut }

    public var breathsPerMinute: Double { cycleSeconds > 0 ? 60.0 / cycleSeconds : 0 }
}

public struct Practice: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let dimension: WellnessDimension
    public let minutes: Int
    public let kind: PracticeKind
    public let summary: String
    public let steps: [String]
    public let prompts: [String]
    public let checklist: [String]
    public let breathing: BreathingPattern?
    public let reference: String
    public let verse: String
    public let evidence: String
    public let evidenceLevel: EvidenceLevel
    public let citations: [String]
    public let needs: [WellbeingNeed]

    public init(id: String, title: String, subtitle: String, dimension: WellnessDimension, minutes: Int,
                kind: PracticeKind, summary: String, steps: [String], prompts: [String] = [],
                checklist: [String] = [], breathing: BreathingPattern? = nil, reference: String,
                verse: String, evidence: String, evidenceLevel: EvidenceLevel, citations: [String],
                needs: [WellbeingNeed]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.dimension = dimension
        self.minutes = minutes
        self.kind = kind
        self.summary = summary
        self.steps = steps
        self.prompts = prompts
        self.checklist = checklist
        self.breathing = breathing
        self.reference = reference
        self.verse = verse
        self.evidence = evidence
        self.evidenceLevel = evidenceLevel
        self.citations = citations
        self.needs = needs
    }
}

public struct Citation: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let authors: String
    public let year: Int
    public let title: String
    public let source: String
    public let doi: String?
    /// In-text citation, e.g. "Seligman et al., 2005".
    public let short: String

    public init(id: String, authors: String, year: Int, title: String, source: String, doi: String?, short: String) {
        self.id = id
        self.authors = authors
        self.year = year
        self.title = title
        self.source = source
        self.doi = doi
        self.short = short
    }

    public var url: URL? {
        guard let doi, !doi.isEmpty else { return nil }
        return URL(string: "https://doi.org/\(doi)")
    }

    /// A readable APA-style reference.
    public var formatted: String {
        var text = "\(authors) (\(year)). \(title). \(source)."
        if let doi, !doi.isEmpty { text += " https://doi.org/\(doi)" }
        return text
    }
}

/// An English word whose history illuminates faith and wellness.
public struct Etymology: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let word: String
    public let origin: String
    public let root: String?
    public let related: [String]
    public let insight: String
    public let reference: String?
    public let verse: String?

    public init(id: String, word: String, origin: String, root: String?, related: [String], insight: String,
                reference: String?, verse: String?) {
        self.id = id
        self.word = word
        self.origin = origin
        self.root = root
        self.related = related
        self.insight = insight
        self.reference = reference
        self.verse = verse
    }
}
