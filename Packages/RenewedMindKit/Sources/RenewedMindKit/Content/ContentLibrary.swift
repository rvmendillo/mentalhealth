import Foundation

public enum ContentError: Error, LocalizedError, Equatable {
    case missingResource(String)
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "Missing bundled content file: \(name)"
        case .invalid(let reason): return "Invalid bundled content: \(reason)"
        }
    }
}

/// All bundled, verified content: affirmations, practices, citations, and etymologies.
public final class ContentLibrary: Sendable {
    public let affirmations: [Affirmation]
    public let practices: [Practice]
    public let citations: [Citation]
    public let etymologies: [Etymology]

    private let affirmationIndex: [String: Int]
    private let practiceIndex: [String: Int]
    private let citationIndex: [String: Int]
    /// A fixed, theme-interleaved order used for "affirmation of the day".
    private let dailyOrder: [Int]

    public init(affirmations: [Affirmation], practices: [Practice], citations: [Citation], etymologies: [Etymology]) throws {
        guard !affirmations.isEmpty else { throw ContentError.invalid("no affirmations") }
        guard !practices.isEmpty else { throw ContentError.invalid("no practices") }
        self.affirmations = affirmations
        self.practices = practices
        self.citations = citations
        self.etymologies = etymologies
        self.affirmationIndex = try Self.index(affirmations.map(\.id), kind: "affirmation")
        self.practiceIndex = try Self.index(practices.map(\.id), kind: "practice")
        self.citationIndex = try Self.index(citations.map(\.id), kind: "citation")
        self.dailyOrder = Self.interleavedOrder(affirmations)
    }

    private static func index(_ ids: [String], kind: String) throws -> [String: Int] {
        var map: [String: Int] = [:]
        for (i, id) in ids.enumerated() {
            if map[id] != nil { throw ContentError.invalid("duplicate \(kind) id \(id)") }
            map[id] = i
        }
        return map
    }

    /// Round-robin across themes so consecutive days visit different themes.
    private static func interleavedOrder(_ affirmations: [Affirmation]) -> [Int] {
        var buckets: [[Int]] = Theme.allCases.map { theme in
            affirmations.indices.filter { affirmations[$0].theme == theme }
        }
        var order: [Int] = []
        var round = 0
        while order.count < affirmations.count {
            var progressed = false
            for b in buckets.indices where round < buckets[b].count {
                order.append(buckets[b][round])
                progressed = true
            }
            if !progressed { break }
            round += 1
        }
        buckets.removeAll()
        return order
    }

    // MARK: Loading

    public static func loadBundled() throws -> ContentLibrary {
        try load(from: Bundle.module)
    }

    public static func load(from bundle: Bundle) throws -> ContentLibrary {
        let decoder = JSONDecoder()
        func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            guard let url = bundle.url(forResource: name, withExtension: "json") else {
                throw ContentError.missingResource("\(name).json")
            }
            return try decoder.decode(T.self, from: Data(contentsOf: url))
        }
        return try ContentLibrary(
            affirmations: try decode([Affirmation].self, "affirmations"),
            practices: try decode([Practice].self, "practices"),
            citations: try decode([Citation].self, "citations"),
            etymologies: try decode([Etymology].self, "etymologies"))
    }

    /// The shared, bundled library. Content is validated by the test suite, so failure here is a build defect.
    public static let shared: ContentLibrary = {
        do {
            return try loadBundled()
        } catch {
            fatalError("RenewedMindKit content failed to load: \(error)")
        }
    }()

    // MARK: Lookup

    public func affirmation(id: String) -> Affirmation? {
        affirmationIndex[id].map { affirmations[$0] }
    }

    public func affirmations(for theme: Theme) -> [Affirmation] {
        affirmations.filter { $0.theme == theme }
    }

    public func practice(id: String) -> Practice? {
        practiceIndex[id].map { practices[$0] }
    }

    public func practices(for dimension: WellnessDimension) -> [Practice] {
        practices.filter { $0.dimension == dimension }
    }

    public func citation(id: String) -> Citation? {
        citationIndex[id].map { citations[$0] }
    }

    public func citations(for practice: Practice) -> [Citation] {
        practice.citations.compactMap { citation(id: $0) }
    }

    /// Simple case-insensitive search over affirmations.
    public func search(_ query: String) -> [Affirmation] {
        let q = TextTools.normalize(query)
        guard !q.isEmpty else { return affirmations }
        return affirmations.filter { a in
            [a.affirmation, a.reference, a.verse, a.theme.title, a.wordStudy.transliteration,
             a.wordStudy.english, a.wordStudy.meaning, a.wordStudy.strongs]
                .contains { TextTools.normalize($0).contains(q) }
        }
    }

    // MARK: Affirmation of the day

    /// Number of whole days between 1 January 2024 and `date` in `calendar` (time-zone aware).
    public static func dayNumber(for date: Date, calendar: Calendar) -> Int {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        let reference = calendar.date(from: components) ?? Date(timeIntervalSince1970: 1_704_067_200)
        let start = calendar.startOfDay(for: reference)
        let day = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: day).day ?? 0
    }

    public func dailyAffirmation(for date: Date = Date(), calendar: Calendar = .current) -> Affirmation {
        let n = Self.dayNumber(for: date, calendar: calendar)
        let count = dailyOrder.count
        let position = ((n % count) + count) % count
        return affirmations[dailyOrder[position]]
    }
}
