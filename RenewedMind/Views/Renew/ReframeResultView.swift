import SwiftUI
import RenewedMindKit

/// Shows a freshly generated reframe and lets the person save it.
struct ReframeResultView: View {
    @EnvironmentObject private var model: AppModel
    let pending: PendingReframe
    var onSaved: () -> Void

    @State private var ownWords = ""
    @State private var intensityAfter: Double = 50
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    SectionLabel(title: "Your thought", systemImage: "text.quote")
                    Text(pending.thought)
                        .font(.body)
                        .accessibilityIdentifier("result.thought")
                }
                ReframeContentView(result: pending.result)
                if pending.result.crisisLevel < .urgent {
                    Card {
                        SectionLabel(title: "In your own words", systemImage: "quote.bubble")
                        Text("Try rewriting the balanced thought so it sounds like you.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("My balanced thought…", text: $ownWords, axis: .vertical)
                            .lineLimit(2...6)
                            .padding(12)
                            .background(Palette.backgroundTop, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityIdentifier("result.ownWords")
                    }
                    if let before = pending.intensityBefore {
                        Card {
                            SectionLabel(title: "How strong is it now?", systemImage: "gauge.with.dots.needle.33percent")
                            Slider(value: $intensityAfter, in: 0...100, step: 5)
                                .accessibilityLabel("Intensity now")
                                .accessibilityValue("\(Int(intensityAfter)) out of 100")
                            HStack {
                                Text("Before: \(before)")
                                Spacer()
                                Text("Now: \(Int(intensityAfter))")
                                    .foregroundStyle(Int(intensityAfter) < before ? Palette.teal : .primary)
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                Button {
                    model.saveReframe(thought: pending.thought, emotion: pending.emotion,
                                      intensityBefore: pending.intensityBefore,
                                      intensityAfter: pending.intensityBefore == nil ? nil : Int(intensityAfter),
                                      result: pending.result, ownBalancedThought: ownWords)
                    saved = true
                    onSaved()
                } label: {
                    Label(saved ? "Saved" : "Save to my journal", systemImage: saved ? "checkmark" : "tray.and.arrow.down")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(saved)
                .accessibilityIdentifier("result.save")
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle("A healthier perspective")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let before = pending.intensityBefore { intensityAfter = Double(before) }
        }
    }
}

/// The body of a reframe result. Shared by new and saved reflections.
struct ReframeContentView: View {
    @EnvironmentObject private var model: AppModel
    let result: ReframeResult
    @State private var showingDistortion: CognitiveDistortion?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if result.crisisLevel != CrisisLevel.none {
                SafetyBanner(level: result.crisisLevel)
            }
            Card {
                SectionLabel(title: "First, a word of care", systemImage: "heart", color: Palette.rose)
                Text(result.validation)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("result.validation")
            }
            if !result.distortions.isEmpty {
                Card {
                    SectionLabel(title: "Thinking patterns noticed", systemImage: "magnifyingglass")
                    ForEach(result.distortions) { detected in
                        Button {
                            showingDistortion = detected.distortion
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(detected.distortion.info.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(Palette.teal)
                                }
                                if !detected.evidence.isEmpty {
                                    Text("“\(detected.evidence)”")
                                        .font(.subheadline.italic())
                                        .foregroundStyle(Palette.rose)
                                }
                                Text(detected.explanation ?? detected.distortion.info.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("result.distortion.\(detected.distortion.rawValue)")
                    }
                }
            }
            if !result.questions.isEmpty {
                Card {
                    SectionLabel(title: "Questions to consider", systemImage: "questionmark.bubble")
                    ForEach(Array(result.questions.enumerated()), id: \.offset) { _, question in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(Palette.teal)
                            Text(question).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Card {
                SectionLabel(title: "A healthier perspective", systemImage: "sun.horizon", color: Palette.teal)
                Text(result.balancedThought)
                    .font(.system(.title3, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("result.balanced")
            }
            if let affirmation = model.library.affirmation(id: result.affirmationID) {
                Card {
                    SectionLabel(title: "Truth to stand on", systemImage: "book.closed", color: Palette.gold)
                    VerseView(verse: affirmation.verse, reference: affirmation.reference)
                    WordStudyCard(study: affirmation.wordStudy, expanded: false)
                    NavigationLink("Read the full word study") {
                        AffirmationDetailView(affirmation: affirmation)
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            Card {
                SectionLabel(title: "Your affirmation", systemImage: "sparkles", color: Palette.gold)
                Text(result.personalAffirmation)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("result.affirmation")
            }
            Card {
                SectionLabel(title: "One small step", systemImage: "figure.walk")
                Text(result.nextStep)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let id = result.suggestedPracticeID, let practice = model.library.practice(id: id) {
                    NavigationLink {
                        PracticeDetailView(practice: practice)
                    } label: {
                        PracticeRow(practice: practice)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("result.practice")
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Label(sourceLine, systemImage: result.source == .offline ? "lock.shield" : "sparkles")
                if let notice = result.notice {
                    Text(notice)
                }
                Text("This reflection is for encouragement and growth, not a diagnosis or a substitute for professional care.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("result.source")
        }
        .sheet(item: $showingDistortion) { distortion in
            NavigationStack {
                DistortionDetailView(distortion: distortion)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingDistortion = nil }
                        }
                    }
            }
            .environmentObject(model)
            .presentationDetents([.medium, .large])
        }
    }

    private var sourceLine: String {
        switch result.source {
        case .offline: return "Offline guide · on this device"
        case .onDevice: return "Apple Intelligence · on this device"
        case .claude:
            if let id = result.modelID, let model = ClaudeModel(rawValue: id) { return "Reflection by \(model.displayName)" }
            return "Reflection by Claude" + (result.modelID.map { " (\($0))" } ?? "")
        }
    }
}
