import SwiftUI
import RenewedMindKit

struct PracticesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.recommendations()) { recommendation in
                        if let practice = model.library.practice(id: recommendation.practiceID) {
                            NavigationLink {
                                PracticeDetailView(practice: practice)
                            } label: {
                                PracticeRow(practice: practice, reason: recommendation.reasons.first)
                            }
                        }
                    }
                } header: {
                    Text("Recommended for you")
                } footer: {
                    Text("Suggestions adapt to your check-ins and to what you say helps — and rotate to keep things fresh.")
                }
                ForEach(WellnessDimension.allCases) { dimension in
                    let practices = model.library.practices(for: dimension)
                    if !practices.isEmpty {
                        Section {
                            ForEach(practices) { practice in
                                NavigationLink {
                                    PracticeDetailView(practice: practice)
                                } label: {
                                    PracticeRow(practice: practice)
                                }
                                .accessibilityIdentifier("practice.\(practice.id)")
                            }
                        } header: {
                            Label(dimension.title, systemImage: dimension.symbol)
                                .foregroundStyle(Palette.color(for: dimension))
                        }
                    }
                }
            }
            .navigationTitle("Practices")
        }
    }
}

struct PracticeDetailView: View {
    @EnvironmentObject private var model: AppModel
    let practice: Practice
    @State private var activeSession: PracticeSessionRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Label(practice.dimension.title, systemImage: practice.dimension.symbol)
                        .foregroundStyle(Palette.color(for: practice.dimension))
                    Text("·").foregroundStyle(.secondary)
                    Text("\(practice.minutes) min").foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                Text(practice.subtitle)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.secondary)
                Text(practice.summary)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                VerseView(verse: practice.verse, reference: practice.reference)
                Card {
                    SectionLabel(title: "How to", systemImage: "list.number")
                    ForEach(Array(practice.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Palette.teal, in: Circle())
                            Text(step)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Button {
                    activeSession = PracticeSessionRoute(practice: practice)
                } label: {
                    Label("Begin", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("practice.begin")
                Card {
                    SectionLabel(title: "The science", systemImage: "flask", color: Palette.teal)
                    Text(practice.evidenceLevel.title)
                        .font(.caption.weight(.bold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Palette.teal.opacity(0.12), in: Capsule())
                        .foregroundStyle(Palette.teal)
                    Text(practice.evidence)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(model.library.citations(for: practice)) { citation in
                        CitationRow(citation: citation)
                    }
                }
                let past = model.journalEntries(for: practice.id)
                if !past.isEmpty {
                    Card {
                        SectionLabel(title: "Your past entries", systemImage: "book")
                        ForEach(past.prefix(5)) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(entry.responses.enumerated()), id: \.offset) { _, response in
                                    if !response.isEmpty {
                                        Text(response).font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle(practice.title)
        .fullScreenCover(item: $activeSession) { route in
            PracticeSessionView(practice: route.practice)
                .environmentObject(model)
        }
    }
}

struct PracticeSessionRoute: Identifiable {
    let id = UUID()
    let practice: Practice
}

struct CitationRow: View {
    let citation: Citation

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(citation.short)
                .font(.caption.weight(.semibold))
            Text("\(citation.title). \(citation.source).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let url = citation.url {
                Link("doi.org/\(citation.doi ?? "")", destination: url)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
