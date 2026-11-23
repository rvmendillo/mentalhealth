import Foundation

/// Anything that can produce an AI reframe (Claude, Apple's on-device model, or a test double).
public protocol AIReframer: Sendable {
    var source: ReframeSource { get }
    func reframe(thought: String, analysis: ReframeEngine.Analysis, library: ContentLibrary) async throws -> AIReframeOutput
}

/// Uses Claude through the Messages API with structured outputs.
public struct ClaudeReframer: AIReframer {
    public let client: ClaudeClient
    public let model: ClaudeModel

    public init(client: ClaudeClient, model: ClaudeModel) {
        self.client = client
        self.model = model
    }

    public var source: ReframeSource { .claude }

    public func reframe(thought: String, analysis: ReframeEngine.Analysis,
                        library: ContentLibrary) async throws -> AIReframeOutput {
        let system = ReframePrompt.systemPrompt(library: library)
        let user = ReframePrompt.userMessage(thought: thought, analysis: analysis)
        let schema = ReframePrompt.responseSchema(library: library)
        var lastError: Error = ClaudeError.invalidResponse
        for candidate in model.chain {
            do {
                let reply = try await client.send(model: candidate, system: system, user: user, schema: schema)
                var output = try ReframePrompt.parse(reply.text, library: library)
                output.modelID = reply.model ?? candidate.rawValue
                return output
            } catch let error as ClaudeError where error.allowsModelFallback {
                lastError = error
                continue
            }
        }
        throw lastError
    }
}

/// Combines the offline engine with an optional AI model. The offline engine always runs first:
/// it screens for crisis language (never sent to AI when urgent) and provides a fallback.
public struct ReframeCoordinator: Sendable {
    public let engine: ReframeEngine

    public init(library: ContentLibrary) {
        engine = ReframeEngine(library: library)
    }

    public func reframe(_ thought: String, ai: AIReframer?) async -> ReframeResult {
        let analysis = engine.analyze(thought)
        let offline = engine.reframe(thought, analysis: analysis)
        guard analysis.crisis.level < .urgent, let ai else { return offline }
        do {
            let output = try await ai.reframe(thought: thought, analysis: analysis, library: engine.library)
            return Self.merge(offline: offline, ai: output, source: ai.source, library: engine.library)
        } catch is CancellationError {
            return offline
        } catch {
            var result = offline
            let reason = (error as? LocalizedError)?.errorDescription ?? "The AI guide wasn't available."
            result.notice = "\(reason) Showing the offline reflection instead."
            result.errorDetail = String(reflecting: error)
            return result
        }
    }

    public static func merge(offline: ReframeResult, ai: AIReframeOutput, source: ReframeSource,
                             library: ContentLibrary) -> ReframeResult {
        var result = offline
        result.source = source
        result.modelID = ai.modelID
        result.validation = ai.validation
        result.distortions = ai.distortions
        if !ai.questions.isEmpty { result.questions = ai.questions }
        result.balancedThought = ai.balancedThought
        if let id = ai.affirmationID, library.affirmation(id: id) != nil {
            result.affirmationID = id
        }
        if !ai.personalAffirmation.isEmpty {
            result.personalAffirmation = ai.personalAffirmation
        } else if let affirmation = library.affirmation(id: result.affirmationID) {
            result.personalAffirmation = affirmation.affirmation
        }
        if !ai.nextStep.isEmpty { result.nextStep = ai.nextStep }
        if let practiceID = ai.practiceID { result.suggestedPracticeID = practiceID }
        if ai.safetyConcern { result.crisisLevel = max(result.crisisLevel, .concern) }
        result.notice = nil
        return result
    }
}
