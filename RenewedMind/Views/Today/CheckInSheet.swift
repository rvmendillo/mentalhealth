import SwiftUI
import RenewedMindKit

struct CheckInSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var mood: Int
    @State private var factors: Set<CheckInFactor> = []
    @State private var note = ""

    init(initialMood: Int) {
        _mood = State(initialValue: min(max(initialMood, 1), 5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How are you feeling?")
                            .font(.headline)
                        HStack {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    mood = value
                                    Haptics.tap()
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(CheckIn.moodEmoji[value - 1])
                                            .font(.system(size: 36))
                                            .opacity(mood == value ? 1 : 0.45)
                                            .scaleEffect(mood == value ? 1.12 : 1)
                                        Text(CheckIn.moodLabels[value - 1])
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                            .foregroundStyle(mood == value ? Palette.teal : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Mood: \(CheckIn.moodLabels[value - 1])")
                                .accessibilityAddTraits(mood == value ? .isSelected : [])
                                .accessibilityIdentifier("checkin.mood.\(value)")
                            }
                        }
                    }
                    factorSection(title: "What's weighing on you?", factors: CheckInFactor.challenges, color: Palette.rose)
                    factorSection(title: "What's going well?", factors: CheckInFactor.strengths, color: Palette.teal)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anything else? (optional)")
                            .font(.headline)
                        TextField("A word or two about today", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(12)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityIdentifier("checkin.note")
                    }
                    Text("Check-ins personalize your recommendations. Everything stays on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let ordered = CheckInFactor.allCases.filter { factors.contains($0) }
                        model.addCheckIn(mood: mood, factors: ordered, note: note)
                        dismiss()
                    }
                    .accessibilityIdentifier("checkin.save")
                }
            }
        }
    }

    private func factorSection(title: String, factors list: [CheckInFactor], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(list) { factor in
                    Button {
                        if factors.contains(factor) { factors.remove(factor) } else { factors.insert(factor) }
                        Haptics.tap()
                    } label: {
                        Chip(title: factor.title, isSelected: factors.contains(factor), color: color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("checkin.factor.\(factor.rawValue)")
                }
            }
        }
    }
}
