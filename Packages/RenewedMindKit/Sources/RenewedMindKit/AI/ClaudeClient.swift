import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Claude models the app can use. Defaults to Anthropic's most capable widely released model.
public enum ClaudeModel: String, Codable, CaseIterable, Sendable, Identifiable {
    case fable52 = "claude-fable-5-2"
    case opus55 = "claude-opus-5-5"
    case sonnet55 = "claude-sonnet-5-5"
    case haiku55 = "claude-haiku-5-5"

    public static let `default`: ClaudeModel = .fable52

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fable52: return "Claude Fable 5.2"
        case .opus55: return "Claude Opus 5.5"
        case .sonnet55: return "Claude Sonnet 5.5"
        case .haiku55: return "Claude Haiku 5.5"
        }
    }

    public var detail: String {
        switch self {
        case .fable52: return "Anthropic's most capable model. Deepest, most thoughtful reflections."
        case .opus55: return "Excellent quality, faster, and lower cost."
        case .sonnet55: return "Fast and capable for everyday use."
        case .haiku55: return "Fastest and lowest cost."
        }
    }

    /// Reasoning effort sent in `output_config.effort`.
    public var effort: String { "medium" }

    /// Server-side refusal fallbacks (`fallbacks: "default"`) are supported on these models; not on Haiku.
    public var usesServerFallbacks: Bool { self != .haiku55 }

    /// Models to try in order. If an account cannot use Fable (for example, data-retention settings),
    /// the request is retried on Opus 5.5.
    public var chain: [ClaudeModel] {
        switch self {
        case .fable52: return [.fable52, .opus55]
        default: return [self]
        }
    }
}

public enum ClaudeError: Error, Equatable, LocalizedError, Sendable {
    case missingAPIKey
    case invalidAPIKey
    case billing(String)
    case permissionDenied(String)
    case modelUnavailable(String)
    case badRequest(String)
    case rateLimited(retryAfter: Int?)
    case overloaded
    case server(status: Int)
    case refused
    case truncated
    case invalidResponse
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your Anthropic API key in Settings to use Claude."
        case .invalidAPIKey: return "Your Anthropic API key was not accepted. Check it in Settings."
        case .billing(let message): return "Your Anthropic account needs attention (billing). \(message)"
        case .permissionDenied(let message): return "Your API key doesn't have permission for this request. \(message)"
        case .modelUnavailable(let message): return "That Claude model isn't available to your account. \(message)"
        case .badRequest(let message): return "Claude couldn't process the request. \(message)"
        case .rateLimited: return "Claude is receiving too many requests right now. Please try again in a moment."
        case .overloaded: return "Claude is busy right now. Please try again shortly."
        case .server(let status): return "Claude had a problem (error \(status)). Please try again."
        case .refused: return "Claude declined to respond to this one."
        case .truncated: return "Claude's response was cut off."
        case .invalidResponse: return "Claude's response couldn't be read."
        case .network(let message): return "Couldn't reach Claude. \(message)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .overloaded, .server, .network: return true
        case .rateLimited(let retryAfter): return retryAfter != nil
        default: return false
        }
    }

    /// Errors where trying the next model in the chain may succeed.
    var allowsModelFallback: Bool {
        switch self {
        case .badRequest, .permissionDenied, .modelUnavailable: return true
        default: return false
        }
    }
}

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(timeout: TimeInterval = 120) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        session = URLSession(configuration: configuration)
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: ClaudeError.network(error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(throwing: ClaudeError.invalidResponse)
                    return
                }
                continuation.resume(returning: (data ?? Data(), http))
            }
            task.resume()
        }
    }
}

public struct ClaudeReply: Equatable, Sendable {
    public let text: String
    public let model: String?
    public let stopReason: String?
}

/// Minimal Claude Messages API client (raw HTTP; Anthropic has no official Swift SDK).
public struct ClaudeClient: Sendable {
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let apiVersion = "2026-10-21"
    public static let fallbackBeta = "server-side-fallback-2026-07-01"
    public static let maxTokens = 16_000

    public let apiKey: String
    public let transport: HTTPTransport
    public let maxRetries: Int
    private let sleeper: @Sendable (UInt64) async throws -> Void

    public init(apiKey: String, transport: HTTPTransport = URLSessionTransport(), maxRetries: Int = 2,
                sleeper: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transport = transport
        self.maxRetries = maxRetries
        self.sleeper = sleeper
    }

    /// Builds the JSON body for a structured-output request.
    public static func makeBody(model: ClaudeModel, system: String, user: String, schema: [String: Any]) -> [String: Any] {
        var body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": maxTokens,
            "system": [
                ["type": "text", "text": system, "cache_control": ["type": "ephemeral"]] as [String: Any],
            ],
            "messages": [
                ["role": "user", "content": user],
            ],
            "output_config": [
                "effort": model.effort,
                "format": ["type": "json_schema", "schema": schema] as [String: Any],
            ] as [String: Any],
        ]
        if model.usesServerFallbacks {
            body["fallbacks"] = "default"
        }
        return body
    }

    public func makeRequest(model: ClaudeModel, system: String, user: String, schema: [String: Any]) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw ClaudeError.missingAPIKey }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        if model.usesServerFallbacks {
            request.setValue(Self.fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        }
        let body = Self.makeBody(model: model, system: system, user: user, schema: schema)
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return request
    }

    private struct MessageResponse: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        let model: String?
        let content: [Block]
        let stop_reason: String?
    }

    private struct ErrorEnvelope: Decodable {
        struct Inner: Decodable {
            let type: String?
            let message: String?
        }
        let error: Inner?
    }

    static func errorMessage(from data: Data) -> String {
        (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error?.message ?? ""
    }

    /// Maps an HTTP response to text or a typed error.
    static func interpret(data: Data, response: HTTPURLResponse) throws -> ClaudeReply {
        let status = response.statusCode
        switch status {
        case 200:
            guard let decoded = try? JSONDecoder().decode(MessageResponse.self, from: data) else {
                throw ClaudeError.invalidResponse
            }
            if decoded.stop_reason == "refusal" { throw ClaudeError.refused }
            if decoded.stop_reason == "max_tokens" { throw ClaudeError.truncated }
            let text = decoded.content.filter { $0.type == "text" }.compactMap(\.text).joined()
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ClaudeError.invalidResponse
            }
            return ClaudeReply(text: text, model: decoded.model, stopReason: decoded.stop_reason)
        case 400, 413:
            throw ClaudeError.badRequest(errorMessage(from: data))
        case 401:
            throw ClaudeError.invalidAPIKey
        case 402:
            throw ClaudeError.billing(errorMessage(from: data))
        case 403:
            throw ClaudeError.permissionDenied(errorMessage(from: data))
        case 404:
            throw ClaudeError.modelUnavailable(errorMessage(from: data))
        case 429:
            let header = response.value(forHTTPHeaderField: "retry-after")
            throw ClaudeError.rateLimited(retryAfter: header.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) })
        case 529:
            throw ClaudeError.overloaded
        default:
            if status >= 500 { throw ClaudeError.server(status: status) }
            throw ClaudeError.badRequest("HTTP \(status). \(errorMessage(from: data))")
        }
    }

    /// Sends a structured-output request, retrying transient failures with backoff.
    public func send(model: ClaudeModel, system: String, user: String, schema: [String: Any]) async throws -> ClaudeReply {
        let request = try makeRequest(model: model, system: system, user: user, schema: schema)
        var attempt = 0
        while true {
            do {
                let (data, response) = try await transport.data(for: request)
                return try Self.interpret(data: data, response: response)
            } catch let error as ClaudeError {
                guard error.isRetryable, attempt < maxRetries else { throw error }
                var delaySeconds = Double(1 << attempt)
                if case .rateLimited(let retryAfter?) = error {
                    guard retryAfter <= 20 else { throw error }
                    delaySeconds = Double(max(retryAfter, 1))
                }
                try await sleeper(UInt64(delaySeconds * 1_000_000_000))
                attempt += 1
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let wrapped = ClaudeError.network(error.localizedDescription)
                guard attempt < maxRetries else { throw wrapped }
                try await sleeper(UInt64(Double(1 << attempt) * 1_000_000_000))
                attempt += 1
            }
        }
    }
}
