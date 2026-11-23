import SwiftUI
import RenewedMindKit

/// Full-screen container that runs a practice, then asks whether it helped.
struct PracticeSessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let practice: Practice
    @State private var startDate = Date()
    @State private var finishedSessionID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if let sessionID = finishedSessionID {
                    PracticeFeedbackView(practice: practice) { feedback in
                        if let feedback { model.setFeedback(feedback, sessionID: sessionID) }
                        dismiss()
                    }
                } else {
                    content
                }
            }
            .background(AppBackground())
            .navigationTitle(practice.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if finishedSessionID == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                            .accessibilityIdentifier("session.close")
                    }
                }
            }
        }
        .onAppear { startDate = Date() }
    }

    @ViewBuilder
    private var content: some View {
        switch practice.kind {
        case .breathing:
            BreathingSessionView(practice: practice, onFinish: finish)
        case .journal:
            JournalSessionView(practice: practice, onFinish: finish)
        case .timer:
            TimerSessionView(practice: practice, onFinish: finish)
        case .guided:
            GuidedSessionView(practice: practice, onFinish: finish)
        case .checklist:
            ChecklistSessionView(practice: practice, onFinish: finish)
        }
    }

    private func finish() {
        let seconds = Int(Date().timeIntervalSince(startDate))
        finishedSessionID = model.recordSession(practiceID: practice.id, seconds: seconds)
        Haptics.success()
    }
}

struct PracticeFeedbackView: View {
    let practice: Practice
    var onDone: (PracticeFeedback?) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(Palette.teal)
                .accessibilityHidden(true)
            Text("Well done")
                .font(.system(.largeTitle, design: .serif).weight(.bold))
            Text("Did \(practice.title) help you today?")
                .font(.title3)
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                ForEach(PracticeFeedback.allCases, id: \.self) { feedback in
                    Button(feedback.title) { onDone(feedback) }
                        .buttonStyle(PrimaryButtonStyle(color: feedback == .helped ? Palette.teal : (feedback == .somewhat ? Palette.gold : .gray)))
                        .accessibilityIdentifier("feedback.\(feedback.rawValue)")
                }
                Button("Skip") { onDone(nil) }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            Text("Your answers teach Renewed Mind which practices fit you best.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Breathing

struct BreathingSessionView: View {
    let practice: Practice
    var onFinish: () -> Void

    @State private var totalMinutes = 3
    @State private var isRunning = false
    @State private var phaseLabel = "Ready when you are"
    @State private var scale: CGFloat = 0.55
    @State private var elapsed: Double = 0
    @State private var runner: Task<Void, Never>?

    private var pattern: BreathingPattern {
        practice.breathing ?? BreathingPattern(inhale: 4, exhale: 6, inhaleCue: "Breathe in…", exhaleCue: "Breathe out…")
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Palette.teal.opacity(0.12))
                    .frame(width: 280, height: 280)
                Circle()
                    .fill(LinearGradient(colors: [Palette.teal.opacity(0.85), Palette.gold.opacity(0.65)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 280, height: 280)
                    .scaleEffect(scale)
                Text(phaseLabel)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(40)
                    .shadow(radius: 4)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Breathing guide. \(phaseLabel)")
            .accessibilityIdentifier("breathing.cue")

            if isRunning {
                Text(remainingText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Picker("Length", selection: $totalMinutes) {
                    Text("1 min").tag(1)
                    Text("3 min").tag(3)
                    Text("5 min").tag(5)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
            }
            Text("\(Int(pattern.breathsPerMinute.rounded())) breaths per minute · \(Int(pattern.inhale + pattern.topUp))s in, \(Int(pattern.exhale))s out")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 12) {
                Button(isRunning ? "Pause" : (elapsed > 0 ? "Resume" : "Start")) {
                    isRunning ? pause() : start()
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("breathing.toggle")
                Button("Finish") {
                    pause()
                    onFinish()
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("session.finish")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onDisappear { runner?.cancel() }
    }

    private var remainingText: String {
        let remaining = max(0, Double(totalMinutes * 60) - elapsed)
        return String(format: "%d:%02d remaining", Int(remaining) / 60, Int(remaining) % 60)
    }

    private func start() {
        isRunning = true
        runner?.cancel()
        runner = Task { @MainActor in
            let total = Double(totalMinutes * 60)
            while !Task.isCancelled && elapsed < total {
                await phase(pattern.inhaleCue, to: 1.0, seconds: pattern.inhale)
                if pattern.topUp > 0 { await phase("…a little more", to: 1.08, seconds: pattern.topUp) }
                if pattern.holdIn > 0 { await phase("Hold", to: nil, seconds: pattern.holdIn) }
                await phase(pattern.exhaleCue, to: 0.55, seconds: pattern.exhale)
                if pattern.holdOut > 0 { await phase("Rest", to: nil, seconds: pattern.holdOut) }
            }
            if !Task.isCancelled {
                isRunning = false
                phaseLabel = "Amen."
                onFinish()
            }
        }
    }

    private func pause() {
        runner?.cancel()
        runner = nil
        isRunning = false
        phaseLabel = "Paused"
        withAnimation(.easeInOut(duration: 0.6)) { scale = 0.55 }
    }

    @MainActor
    private func phase(_ label: String, to target: CGFloat?, seconds: Double) async {
        guard !Task.isCancelled, seconds > 0 else { return }
        phaseLabel = label
        Haptics.phase()
        if let target {
            withAnimation(.easeInOut(duration: seconds)) { scale = target }
        }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        if !Task.isCancelled { elapsed += seconds }
    }
}

// MARK: - Journal

struct JournalSessionView: View {
    @EnvironmentObject private var model: AppModel
    let practice: Practice
    var onFinish: () -> Void
    @State private var responses: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(practice.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(practice.prompts.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(practice.prompts[index])
                            .font(.headline)
                        TextField("Write here…", text: binding(for: index), axis: .vertical)
                            .lineLimit(3...8)
                            .padding(12)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityIdentifier("journal.response.\(index)")
                    }
                }
                Button("Save and finish") {
                    model.saveJournal(practiceID: practice.id, responses: responses)
                    onFinish()
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("session.finish")
                Text("Entries are saved privately on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if responses.count != practice.prompts.count {
                responses = Array(repeating: "", count: practice.prompts.count)
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < responses.count ? responses[index] : "" },
            set: { value in
                if index < responses.count { responses[index] = value }
            }
        )
    }
}

// MARK: - Timer

struct TimerSessionView: View {
    let practice: Practice
    var onFinish: () -> Void
    @State private var remaining: Int = 0
    @State private var isRunning = false
    @State private var runner: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Palette.teal.opacity(0.15), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Palette.teal, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                        .accessibilityIdentifier("timer.remaining")
                }
                .frame(width: 220, height: 220)
                .padding(.top, 20)
                HStack(spacing: 12) {
                    Button(isRunning ? "Pause" : "Start") { isRunning ? pause() : start() }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("timer.toggle")
                    Button("Finish") {
                        pause()
                        onFinish()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Palette.gold))
                    .accessibilityIdentifier("session.finish")
                }
                Card {
                    SectionLabel(title: "As you go", systemImage: "list.bullet")
                    ForEach(Array(practice.steps.enumerated()), id: \.offset) { _, step in
                        Label(step, systemImage: "circle.fill")
                            .labelStyle(StepLabelStyle())
                    }
                }
                VerseView(verse: practice.verse, reference: practice.reference)
            }
            .padding()
        }
        .onAppear { if remaining == 0 { remaining = practice.minutes * 60 } }
        .onDisappear { runner?.cancel() }
    }

    private var progress: CGFloat {
        let total = max(1, practice.minutes * 60)
        return CGFloat(total - remaining) / CGFloat(total)
    }

    private func start() {
        isRunning = true
        runner?.cancel()
        runner = Task { @MainActor in
            while !Task.isCancelled && remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled { remaining -= 1 }
            }
            if !Task.isCancelled && remaining == 0 {
                isRunning = false
                Haptics.success()
                onFinish()
            }
        }
    }

    private func pause() {
        runner?.cancel()
        runner = nil
        isRunning = false
    }
}

struct StepLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 10) {
            configuration.icon
                .font(.system(size: 6))
                .foregroundStyle(Palette.teal)
                .padding(.top, 7)
            configuration.title
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Guided steps

struct GuidedSessionView: View {
    let practice: Practice
    var onFinish: () -> Void
    @State private var index = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Step \(index + 1) of \(practice.steps.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 24)
                .accessibilityIdentifier("guided.progress")
            ProgressView(value: Double(index + 1), total: Double(max(1, practice.steps.count)))
                .tint(Palette.teal)
                .padding(.horizontal, 40)
            Spacer()
            Text(practice.steps.isEmpty ? practice.summary : practice.steps[index])
                .font(.system(.title2, design: .serif))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .accessibilityIdentifier("guided.step")
            Spacer()
            if index == practice.steps.count - 1 || practice.steps.isEmpty {
                VerseView(verse: practice.verse, reference: practice.reference, compact: true)
                    .padding(.horizontal)
            }
            HStack(spacing: 12) {
                Button("Back") { index -= 1 }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(index == 0)
                    .opacity(index == 0 ? 0.4 : 1)
                if index < practice.steps.count - 1 {
                    Button("Next") { index += 1; Haptics.tap() }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("guided.next")
                } else {
                    Button("Finish") { onFinish() }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("session.finish")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Checklist

struct ChecklistSessionView: View {
    let practice: Practice
    var onFinish: () -> Void
    @State private var done: Set<Int> = []

    var body: some View {
        List {
            Section {
                Text(practice.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Checklist") {
                ForEach(practice.checklist.indices, id: \.self) { index in
                    Button {
                        if done.contains(index) { done.remove(index) } else { done.insert(index); Haptics.tap() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: done.contains(index) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(done.contains(index) ? Palette.teal : .secondary)
                            Text(practice.checklist[index])
                                .foregroundStyle(.primary)
                        }
                    }
                    .accessibilityIdentifier("checklist.item.\(index)")
                    .accessibilityAddTraits(done.contains(index) ? .isSelected : [])
                }
            }
            Section {
                VerseView(verse: practice.verse, reference: practice.reference)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                Button("Finish") { onFinish() }
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .accessibilityIdentifier("session.finish")
            } footer: {
                Text("\(done.count) of \(practice.checklist.count) done — every step counts.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}
