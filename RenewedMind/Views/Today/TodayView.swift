import SwiftUI
import RenewedMindKit

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingSettings = false
    @State private var showingHelp = false
    @State private var checkInMood: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    AffirmationCard(affirmation: model.dailyAffirmation)
                    if model.needsGentleCheckIn { gentleCareCard }
                    checkInCard
                    renewCard
                    recommendationsCard
                    progressCard
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingHelp = true
                    } label: {
                        Label("Get help", systemImage: "heart.text.square")
                    }
                    .accessibilityIdentifier("today.help")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("today.settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(model)
            }
            .sheet(isPresented: $showingHelp) {
                CrisisResourcesView().environmentObject(model)
            }
            .sheet(item: Binding(
                get: { checkInMood.map { MoodSelection(mood: $0) } },
                set: { checkInMood = $0?.mood }
            )) { selection in
                CheckInSheet(initialMood: selection.mood).environmentObject(model)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Peace to you tonight"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(greeting), \(model.displayName)")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .accessibilityIdentifier("today.greeting")
            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var gentleCareCard: some View {
        Card {
            Label("You've been carrying a lot lately", systemImage: "hands.and.sparkles")
                .font(.headline)
                .foregroundStyle(Palette.rose)
            Text("Your recent check-ins have been low. That matters. Consider talking with someone you trust, your pastor, or a doctor or counselor. You don't have to wait until it gets worse.")
                .font(.subheadline)
            Button("See support options") { showingHelp = true }
                .buttonStyle(SecondaryButtonStyle(color: Palette.rose))
        }
    }

    private var checkInCard: some View {
        Card {
            SectionLabel(title: "Check in", systemImage: "heart")
            if let checkIn = model.todaysCheckIn {
                HStack(spacing: 12) {
                    Text(checkIn.moodEmoji).font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today you're feeling \(checkIn.moodLabel.lowercased())")
                            .font(.headline)
                        if !checkIn.factors.isEmpty {
                            Text(checkIn.factors.map(\.title).joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today.checkInSummary")
                Button("Check in again") { checkInMood = checkIn.mood }
                    .buttonStyle(SecondaryButtonStyle())
            } else {
                Text("How is your heart today?")
                    .font(.headline)
                HStack {
                    ForEach(1...5, id: \.self) { mood in
                        Button {
                            checkInMood = mood
                        } label: {
                            VStack(spacing: 4) {
                                Text(CheckIn.moodEmoji[mood - 1]).font(.system(size: 34))
                                Text(CheckIn.moodLabels[mood - 1])
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mood: \(CheckIn.moodLabels[mood - 1])")
                        .accessibilityIdentifier("today.mood.\(mood)")
                    }
                }
            }
        }
    }

    private var renewCard: some View {
        Card {
            SectionLabel(title: "Renew a thought", systemImage: "arrow.triangle.2.circlepath", color: Palette.teal)
            Text("Is a heavy thought weighing on you? Let's look at it together with compassion, science, and Scripture.")
                .font(.subheadline)
            Button("Write it down") { model.selectedTab = .renew }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("today.renew")
        }
    }

    private var recommendationsCard: some View {
        Card {
            SectionLabel(title: "Recommended for you", systemImage: "sparkles", color: Palette.gold)
            ForEach(model.recommendations()) { recommendation in
                if let practice = model.library.practice(id: recommendation.practiceID) {
                    NavigationLink {
                        PracticeDetailView(practice: practice)
                    } label: {
                        PracticeRow(practice: practice, reason: recommendation.reasons.first)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("today.recommendation.\(practice.id)")
                }
            }
        }
    }

    private var progressCard: some View {
        let flourish = model.flourish
        return Card {
            SectionLabel(title: "Your week", systemImage: "chart.bar")
            HStack(spacing: 20) {
                statistic(value: "\(model.streak)", label: model.streak == 1 ? "day streak" : "day streak")
                statistic(value: "\(flourish.overall)", label: "flourish score")
                statistic(value: "\(model.data.reframes.count)", label: "thoughts renewed")
            }
            if let focus = flourish.focusDimension {
                Text("A gentle focus this week: \(focus.title.lowercased()).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statistic(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(Palette.teal)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct MoodSelection: Identifiable {
    let mood: Int
    var id: Int { mood }
}

struct PracticeRow: View {
    let practice: Practice
    var reason: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: practice.symbol)
                .font(.title3)
                .foregroundStyle(Palette.color(for: practice.dimension))
                .frame(width: 42, height: 42)
                .background(Palette.color(for: practice.dimension).opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(practice.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(reason ?? practice.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Text("\(practice.minutes) min")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
