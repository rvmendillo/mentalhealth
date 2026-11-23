import Foundation
import RenewedMindKit

/// Chooses which AI (if any) should reframe a thought, based on settings and availability.
enum AIRouter {
    struct Choice {
        let reframer: AIReframer?
        /// Shown when the requested AI can't be used.
        let note: String?
        let label: String
    }

    static func choose(mode: AIMode, model: ClaudeModel, apiKey: String?) -> Choice {
        let hasKey = !(apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        func claude() -> AIReframer { ClaudeReframer(client: ClaudeClient(apiKey: apiKey ?? ""), model: model) }
        switch mode {
        case .offline:
            return Choice(reframer: nil, note: nil, label: ReframeSource.offline.title)
        case .claude:
            if hasKey { return Choice(reframer: claude(), note: nil, label: model.displayName) }
            return Choice(reframer: nil, note: "Add your Anthropic API key in Settings to use Claude.", label: ReframeSource.offline.title)
        case .onDevice:
            if let onDevice = OnDeviceAI.makeReframer() {
                return Choice(reframer: onDevice, note: nil, label: ReframeSource.onDevice.title)
            }
            return Choice(reframer: nil, note: OnDeviceAI.status.message, label: ReframeSource.offline.title)
        case .automatic:
            if hasKey { return Choice(reframer: claude(), note: nil, label: model.displayName) }
            if let onDevice = OnDeviceAI.makeReframer() {
                return Choice(reframer: onDevice, note: nil, label: ReframeSource.onDevice.title)
            }
            return Choice(reframer: nil, note: nil, label: ReframeSource.offline.title)
        }
    }
}
