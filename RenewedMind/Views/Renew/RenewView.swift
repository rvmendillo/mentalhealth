import SwiftUI
import RenewedMindKit

struct RenewView: View {
    @EnvironmentObject private var model: AppModel
    @State private var thought = ""
    @State private var emotion = ""
    @State private var intensity: Double = 60
    @State private var rateIntensity = true
    @State private var isWorking = false
    @State private var pending: PendingReframe?
    @FocusState private var editorFocused: Bool

    static let emotions = ["Sad", "Anxious", "Afraid", "Angry", "Ashamed", "Guilty", "Lonely", "Hopeless", "Overwhelmed", "Hurt", "Numb"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("“Be transformed by the renewing of your mind.” — Romans 12:2")
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(.secondary)
                    Card {
                        SectionLabel(title: "What's weighing on you?", systemImage: "pencil")
                        ZStack(alignment: .topLeading) {
                            if thought.isEmpty {
                                Text("Write the thought just as it sounds in your head — for example, “I always mess everything up.”")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $thought)
                                .focused($editorFocused)
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .accessibilityLabel("Your thought")
                                .accessibilityIdentifier("renew.thought")
                        }
                        Text("Feeling")
                            .font(.subheadline.weight(.semibold))
                        FlowLayout(spacing: 8) {
                            ForEach(Self.emotions, id: \.self) { name in
                                Button {
                                    emotion = emotion == name ? "" : name
                                } label: {
                                    Chip(title: name, isSelected: emotion == name, color: Palette.rose)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Toggle("Rate how strong it feels", isOn: $rateIntensity)
                            .font(.subheadline)
                        if rateIntensity {
                            VStack(alignment: .leading) {
                                Slider(value: $intensity, in: 0...100, step: 5)
                                    .accessibilityLabel("Intensity")
                                    .accessibilityValue("\(Int(intensity)) out of 100")
                                Text("Intensity: \(Int(intensity))/100")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button {
                        Task { await renew() }
                    } label: {
                        HStack {
                            if isWorking { ProgressView().tint(.white) }
                            Text(isWorking ? "Reflecting…" : "Renew this thought")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmedThought.isEmpty || isWorking)
                    .opacity(trimmedThought.isEmpty ? 0.5 : 1)
                    .accessibilityIdentifier("renew.submit")

                    HStack(spacing: 6) {
                        Image(systemName: model.aiChoice.reframer == nil ? "lock.shield" : "sparkles")
                        Text("Guide: \(model.aiChoice.label)")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("renew.guideLabel")

                    if !model.recentReframes.isEmpty {
                        Card {
                            SectionLabel(title: "Recently renewed", systemImage: "clock.arrow.circlepath")
                            ForEach(model.recentReframes.prefix(5)) { entry in
                                NavigationLink {
                                    ReframeEntryView(entry: entry)
                                } label: {
                                    ReframeHistoryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                            if model.recentReframes.count > 5 {
                                NavigationLink("See all \(model.recentReframes.count)") {
                                    ReframeHistoryView()
                                }
                                .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Renew")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editorFocused = false }
                }
            }
            .navigationDestination(item: $pending) { pending in
                ReframeResultView(pending: pending) {
                    thought = ""
                    emotion = ""
                    intensity = 60
                    self.pending = nil
                }
            }
        }
    }

    private var trimmedThought: String { thought.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func renew() async {
        guard !trimmedThought.isEmpty, !isWorking else { return }
        editorFocused = false
        isWorking = true
        let text = trimmedThought
        let result = await model.reframe(text)
        isWorking = false
        pending = PendingReframe(thought: text, emotion: emotion,
                                 intensityBefore: rateIntensity ? Int(intensity) : nil, result: result)
    }
}

/// A reframe that has been generated but not yet saved.
struct PendingReframe: Hashable, Identifiable {
    let id = UUID()
    let thought: String
    let emotion: String
    let intensityBefore: Int?
    let result: ReframeResult
}

struct ReframeHistoryRow: View {
    let entry: ReframeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.thought)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(entry.ownBalancedThought.isEmpty ? entry.result.balancedThought : entry.ownBalancedThought)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                if let change = entry.intensityChange, change > 0 {
                    Text("· eased by \(change) points")
                        .foregroundStyle(Palette.teal)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

struct ReframeHistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            ForEach(model.recentReframes) { entry in
                NavigationLink {
                    ReframeEntryView(entry: entry)
                } label: {
                    ReframeHistoryRow(entry: entry)
                }
            }
            .onDelete { offsets in
                let ids = Set(offsets.map { model.recentReframes[$0].id })
                model.deleteReframes(ids: ids)
            }
        }
        .navigationTitle("Renewed thoughts")
        .overlay {
            if model.recentReframes.isEmpty {
                ContentUnavailableView("No saved reflections yet", systemImage: "arrow.triangle.2.circlepath",
                                       description: Text("Thoughts you renew and save will appear here."))
            }
        }
    }
}

/// A saved reframe, read-only.
struct ReframeEntryView: View {
    @EnvironmentObject private var model: AppModel
    let entry: ReframeEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    SectionLabel(title: entry.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    Text(entry.thought).font(.body)
                    if !entry.emotion.isEmpty {
                        Text("Feeling: \(entry.emotion)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let before = entry.intensityBefore, let after = entry.intensityAfter {
                        Text("Intensity: \(before) → \(after)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.teal)
                    }
                }
                if !entry.ownBalancedThought.isEmpty {
                    Card {
                        SectionLabel(title: "In your own words", systemImage: "quote.bubble")
                        Text(entry.ownBalancedThought).font(.system(.body, design: .serif))
                    }
                }
                ReframeContentView(result: entry.result)
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle("Reflection")
        .navigationBarTitleDisplayMode(.inline)
    }
}
