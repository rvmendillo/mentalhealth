import SwiftUI
import Charts
import RenewedMindKit

struct InsightsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingWHO5 = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    moodCard
                    flourishCard
                    wellbeingCard
                    helpsCard
                    historyCard
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Insights")
            .sheet(isPresented: $showingWHO5) {
                WHO5View().environmentObject(model)
            }
        }
    }

    private var moodCard: some View {
        let days = MoodAnalytics.dailyAverages(model.data.checkIns, days: 30)
        let trend = MoodAnalytics.trend(model.data.checkIns)
        return Card {
            HStack {
                SectionLabel(title: "Mood · last 30 days", systemImage: "waveform.path.ecg")
                Spacer()
                Text(trend.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(trend == .declining ? Palette.rose : Palette.teal)
            }
            if days.isEmpty {
                Text("Check in on the Today tab to see your mood over time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(days) { day in
                    LineMark(x: .value("Day", day.day, unit: .day), y: .value("Mood", day.average))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Palette.teal)
                    PointMark(x: .value("Day", day.day, unit: .day), y: .value("Mood", day.average))
                        .foregroundStyle(Palette.teal)
                }
                .chartYScale(domain: 1.0...5.0)
                .chartYAxis {
                    AxisMarks(values: [1.0, 3.0, 5.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(CheckIn.moodEmoji[max(0, min(4, Int(v.rounded()) - 1))])
                            }
                        }
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("Mood chart")
            }
        }
    }

    private var flourishCard: some View {
        let snapshot = model.flourish
        return Card {
            HStack {
                SectionLabel(title: "Flourishing this week", systemImage: "leaf")
                Spacer()
                Text("\(snapshot.overall)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Palette.teal)
                    .accessibilityLabel("Overall \(snapshot.overall) out of 100")
            }
            ForEach(WellnessDimension.allCases) { dimension in
                HStack(spacing: 10) {
                    Label(dimension.title, systemImage: dimension.symbol)
                        .font(.subheadline)
                        .frame(width: 140, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.color(for: dimension).opacity(0.15))
                            Capsule().fill(Palette.color(for: dimension))
                                .frame(width: proxy.size.width * CGFloat(snapshot.score(dimension)) / 100)
                        }
                    }
                    .frame(height: 10)
                    Text("\(snapshot.score(dimension))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(dimension.title): \(snapshot.score(dimension)) out of 100")
            }
            Text("Built from your practices, check-ins, and reflections over the last 7 days. It's a reflection aid, not a clinical measure.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var wellbeingCard: some View {
        Card {
            SectionLabel(title: "Well-being check (WHO-5)", systemImage: "checklist")
            if let latest = model.latestWHO5 {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(latest.percentScore)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(latest.band == .good ? Palette.teal : Palette.rose)
                    Text("/ 100 · \(latest.band.title)")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("insights.who5Score")
                Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("A five-question check, used worldwide, that takes about a minute. Repeat it every couple of weeks to see how you're doing.")
                    .font(.subheadline)
            }
            Button(model.latestWHO5 == nil ? "Take the check" : "Take it again") { showingWHO5 = true }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("insights.takeWHO5")
        }
    }

    private var helpsCard: some View {
        let helpful = model.practicesThatHelp
        return Card {
            SectionLabel(title: "What helps you", systemImage: "hand.thumbsup")
            if helpful.isEmpty {
                Text("After each practice, tell us whether it helped. Over time, your recommendations learn what fits you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(helpful.prefix(5)) { item in
                    HStack {
                        Text(item.practice.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int((item.score * 100).rounded()))% helpful")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.teal)
                    }
                }
                Text("Estimated with Bayesian (Thompson sampling) learning from your ratings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var historyCard: some View {
        let reframes = model.data.reframes
        let changes = reframes.compactMap(\.intensityChange)
        let averageChange = changes.isEmpty ? nil : Double(changes.reduce(0, +)) / Double(changes.count)
        return Card {
            SectionLabel(title: "Your journey", systemImage: "book")
            HStack(spacing: 18) {
                metric("\(reframes.count)", "thoughts renewed")
                metric(averageChange.map { "\(Int($0.rounded()))" } ?? "–", "avg. points eased")
                metric("\(model.data.journal.count)", "journal entries")
            }
            NavigationLink("Renewed thoughts") { ReframeHistoryView() }
                .font(.subheadline.weight(.semibold))
            NavigationLink("Check-in history") { CheckInHistoryView() }
                .font(.subheadline.weight(.semibold))
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.weight(.bold)).foregroundStyle(Palette.teal)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct CheckInHistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(model.data.checkIns.sorted { $0.date > $1.date }) { checkIn in
            HStack(alignment: .top, spacing: 12) {
                Text(checkIn.moodEmoji).font(.title)
                VStack(alignment: .leading, spacing: 4) {
                    Text(checkIn.date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.weight(.semibold))
                    if !checkIn.factors.isEmpty {
                        Text(checkIn.factors.map(\.title).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                    if !checkIn.note.isEmpty {
                        Text(checkIn.note).font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Check-ins")
        .overlay {
            if model.data.checkIns.isEmpty {
                ContentUnavailableView("No check-ins yet", systemImage: "heart",
                                       description: Text("Your daily check-ins will appear here."))
            }
        }
    }
}

struct WHO5View: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [Int?] = Array(repeating: nil, count: WHO5.items.count)
    @State private var result: WHO5Result?

    var body: some View {
        NavigationStack {
            Form {
                if let result {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(result.percentScore) / 100")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(result.band == .good ? Palette.teal : Palette.rose)
                                .accessibilityIdentifier("who5.score")
                            Text(result.band.title).font(.headline)
                            Text(result.band.guidance).font(.subheadline)
                        }
                        .padding(.vertical, 6)
                    }
                    if result.band != .good {
                        Section("Support") {
                            NavigationLink("See support options") {
                                CrisisResourcesList()
                                    .navigationTitle("Get help")
                            }
                        }
                    }
                    Section {
                        Text(WHO5.attribution).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Text("\(WHO5.prompt) Choose how often each statement was true for you.")
                            .font(.subheadline)
                    }
                    ForEach(WHO5.items.indices, id: \.self) { index in
                        Section(WHO5.items[index]) {
                            ForEach(WHO5.options) { option in
                                Button {
                                    answers[index] = option.value
                                    Haptics.tap()
                                } label: {
                                    HStack {
                                        Text(option.label).foregroundStyle(.primary)
                                        Spacer()
                                        if answers[index] == option.value {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.teal)
                                        }
                                    }
                                }
                                .accessibilityIdentifier("who5.q\(index).a\(option.value)")
                                .accessibilityAddTraits(answers[index] == option.value ? .isSelected : [])
                            }
                        }
                    }
                    Section {
                        Button("See my result") { submit() }
                            .disabled(answers.contains { $0 == nil })
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .accessibilityIdentifier("who5.submit")
                    } footer: {
                        Text(WHO5.attribution)
                    }
                }
            }
            .navigationTitle("Well-being check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(result == nil ? "Cancel" : "Done") { dismiss() }
                        .accessibilityIdentifier("who5.done")
                }
            }
        }
    }

    private func submit() {
        let values = answers.compactMap { $0 }
        guard values.count == WHO5.items.count else { return }
        do {
            result = try model.saveWHO5(answers: values)
            Haptics.success()
        } catch {
            model.alertMessage = "Couldn't score the check. Please answer every question."
        }
    }
}
