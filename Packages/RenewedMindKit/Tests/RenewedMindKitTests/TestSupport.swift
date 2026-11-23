import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import RenewedMindKit

enum TestSupport {
    static let library: ContentLibrary = ContentLibrary.shared

    static func calendar(_ identifier: String = "America/New_York") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0,
                     calendar: Calendar = TestSupport.calendar()) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return calendar.date(from: c)!
    }

    static func temporaryURL(_ name: String = "data.json") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("RenewedMindTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name)
    }

    /// Every object in a JSON schema must set additionalProperties=false and require all its properties.
    static func schemaProblems(_ node: Any, path: String = "$") -> [String] {
        var problems: [String] = []
        if let dict = node as? [String: Any] {
            if (dict["type"] as? String) == "object" {
                if (dict["additionalProperties"] as? Bool) != false { problems.append("\(path): additionalProperties must be false") }
                let props = (dict["properties"] as? [String: Any]) ?? [:]
                let required = Set((dict["required"] as? [String]) ?? [])
                if Set(props.keys) != required { problems.append("\(path): required must list all properties") }
            }
            for (key, value) in dict { problems += schemaProblems(value, path: "\(path).\(key)") }
        } else if let array = node as? [Any] {
            for (i, value) in array.enumerated() { problems += schemaProblems(value, path: "\(path)[\(i)]") }
        }
        return problems
    }
}

/// Records requests and replays canned responses.
final class MockTransport: HTTPTransport, @unchecked Sendable {
    enum Reply {
        case http(Int, String, [String: String])
        case failure(Error)
    }
    private let lock = NSLock()
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [Reply]) { self.replies = replies }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let reply: Reply = lock.withLock {
            requests.append(request)
            return replies.isEmpty ? .http(500, "{}", [:]) : replies.removeFirst()
        }
        switch reply {
        case .failure(let error):
            throw error
        case .http(let status, let body, let headers):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            return (Data(body.utf8), response)
        }
    }

    var requestCount: Int { lock.withLock { requests.count } }

    func body(at index: Int) -> [String: Any] {
        let request = lock.withLock { requests[index] }
        return (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
    }
}

/// Records sleep calls instead of sleeping.
final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var calls: [UInt64] = []
    func record(_ ns: UInt64) { lock.withLock { calls.append(ns) } }
    var count: Int { lock.withLock { calls.count } }
}

/// A scripted AI reframer for coordinator tests.
final class MockAIReframer: AIReframer, @unchecked Sendable {
    let source: ReframeSource
    private let lock = NSLock()
    private var result: Result<AIReframeOutput, Error>
    private(set) var calls = 0

    init(source: ReframeSource = .claude, result: Result<AIReframeOutput, Error>) {
        self.source = source
        self.result = result
    }

    func reframe(thought: String, analysis: ReframeEngine.Analysis, library: ContentLibrary) async throws -> AIReframeOutput {
        let r: Result<AIReframeOutput, Error> = lock.withLock { calls += 1; return result }
        return try r.get()
    }

    var callCount: Int { lock.withLock { calls } }
}

func messageJSON(text: String, stopReason: String = "end_turn", model: String = "claude-fable-5-2",
                 extraBlocks: String = #"{"type":"thinking","thinking":"","signature":"abc"},"#) -> String {
    let escaped = String(data: try! JSONSerialization.data(withJSONObject: [text], options: []), encoding: .utf8)!
    let textLiteral = String(escaped.dropFirst().dropLast())
    return #"{"id":"msg_1","type":"message","role":"assistant","model":"\#(model)","content":[\#(extraBlocks){"type":"text","text":\#(textLiteral)}],"stop_reason":"\#(stopReason)","stop_details":null,"usage":{"input_tokens":10,"output_tokens":20}}"#
}

let sampleAIJSON = #"""
{"validation":"That sounds really painful, and it makes sense that you feel discouraged.","distortions":[{"id":"overgeneralization","quote":"always","explanation":"One hard day is being treated as a forever pattern."},{"id":"labeling","quote":"I'm a failure","explanation":"A single setback is being turned into your whole identity."}],"questions":["Is it really always?","What would you tell a friend?"],"balanced_thought":"I had a hard day, and I'm still learning. One setback doesn't define me.","affirmation_id":"identity-ephesians-2-10","personal_affirmation":"I am God's workmanship, still being shaped with care.","next_step":"Write down one thing that went okay today.","practice_id":"three-good-things","safety_concern":false}
"""#
