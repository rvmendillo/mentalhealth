import SwiftUI
import RenewedMindKit

struct LibraryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    browse
                } else {
                    searchResults
                }
            }
            .background(AppBackground())
            .navigationTitle("Library")
            .searchable(text: $query, prompt: "Search affirmations, verses, words")
        }
    }

    private var browse: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionLabel(title: "Affirmations by theme", systemImage: "square.grid.2x2")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Theme.allCases) { theme in
                    NavigationLink {
                        ThemeAffirmationsView(theme: theme)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: theme.symbol)
                                .font(.title2)
                                .foregroundStyle(theme.color)
                            Text(theme.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(theme.blurb)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                        .padding(14)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library.theme.\(theme.rawValue)")
                }
            }
            if !model.favoriteAffirmations.isEmpty {
                SectionLabel(title: "Favorites", systemImage: "heart")
                ForEach(model.favoriteAffirmations) { affirmation in
                    AffirmationRow(affirmation: affirmation)
                }
            }
            SectionLabel(title: "Explore", systemImage: "safari")
            VStack(spacing: 10) {
                exploreLink("Healthy etymology", "The stories behind words like health, comfort, and peace.", "character.book.closed") {
                    EtymologyListView()
                }
                exploreLink("Thinking patterns", "A guide to the 12 common thinking traps in CBT.", "brain.head.profile") {
                    DistortionGuideView()
                }
                exploreLink("How we study words", "Principles for sound, healthy word studies.", "checkmark.seal") {
                    WordStudyPrinciplesView()
                }
            }
        }
        .padding()
    }

    private func exploreLink<Destination: View>(_ title: String, _ subtitle: String, _ symbol: String,
                                                @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Palette.teal)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var searchResults: some View {
        let results = model.library.search(query)
        return LazyVStack(alignment: .leading, spacing: 10) {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 40)
            } else {
                ForEach(results) { affirmation in
                    AffirmationRow(affirmation: affirmation)
                }
            }
        }
        .padding()
    }
}

struct AffirmationRow: View {
    let affirmation: Affirmation

    var body: some View {
        NavigationLink {
            AffirmationDetailView(affirmation: affirmation)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(affirmation.affirmation)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                HStack {
                    Text(affirmation.reference)
                        .foregroundStyle(Palette.gold)
                    Text("· \(affirmation.wordStudy.transliteration)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("affirmation.row.\(affirmation.id)")
    }
}

struct ThemeAffirmationsView: View {
    @EnvironmentObject private var model: AppModel
    let theme: Theme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Text(theme.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(model.library.affirmations(for: theme)) { affirmation in
                    AffirmationRow(affirmation: affirmation)
                }
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle(theme.title)
    }
}

struct EtymologyListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("Words carry history. These word origins can deepen how we think about health, faith, and wholeness — told carefully, without the popular myths.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(model.library.etymologies) { etymology in
                    EtymologyCard(etymology: etymology)
                }
                Text("Sources: Online Etymology Dictionary, Wiktionary, and Strong's Exhaustive Concordance. Scripture from the Berean Standard Bible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle("Healthy etymology")
    }
}

struct EtymologyCard: View {
    let etymology: Etymology

    var body: some View {
        Card {
            Text(etymology.word)
                .font(.system(.title3, design: .serif).weight(.semibold))
            Text(etymology.origin)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let root = etymology.root {
                Text(root)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !etymology.related.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(etymology.related, id: \.self) { word in
                        Chip(title: word, color: Palette.gold)
                    }
                }
            }
            Text(etymology.insight)
                .font(.subheadline)
                .foregroundStyle(Palette.teal)
                .fixedSize(horizontal: false, vertical: true)
            if let reference = etymology.reference, let verse = etymology.verse {
                VerseView(verse: verse, reference: reference, compact: true)
            }
        }
        .accessibilityIdentifier("etymology.\(etymology.id)")
    }
}

struct DistortionGuideView: View {
    var body: some View {
        List {
            Section {
                Text("These patterns come from cognitive behavioral therapy (CBT), one of the most researched approaches to mental health. Everyone falls into them sometimes — noticing them is the first step to “taking every thought captive.”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(CognitiveDistortion.allCases) { distortion in
                NavigationLink {
                    DistortionDetailView(distortion: distortion)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(distortion.info.name).font(.headline)
                        Text(distortion.info.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        }
        .navigationTitle("Thinking patterns")
    }
}

struct DistortionDetailView: View {
    @EnvironmentObject private var model: AppModel
    let distortion: CognitiveDistortion

    var body: some View {
        let info = distortion.info
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(info.summary)
                    .font(.body)
                Card {
                    SectionLabel(title: "Sounds like", systemImage: "text.bubble")
                    Text(info.example).font(.system(.body, design: .serif).italic())
                }
                Card {
                    SectionLabel(title: "Ask yourself", systemImage: "questionmark.circle")
                    Text(info.question).font(.body)
                }
                Card {
                    SectionLabel(title: "Try instead", systemImage: "arrow.triangle.2.circlepath")
                    Text(info.reframeTip).font(.body)
                }
                if let affirmation = model.library.affirmation(id: info.affirmationID) {
                    Card {
                        SectionLabel(title: "Truth to stand on", systemImage: "book.closed", color: Palette.gold)
                        Text(affirmation.affirmation).font(.system(.headline, design: .serif))
                        VerseView(verse: affirmation.verse, reference: affirmation.reference, compact: true)
                    }
                }
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle(info.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WordStudyPrinciplesView: View {
    private struct Principle: Identifiable {
        let title: String
        let detail: String
        var id: String { title }
    }

    private let principles: [Principle] = [
        Principle(title: "Context decides meaning", detail: "A word means what it means in its sentence. Roots and history can illuminate, but they don't override how an author uses a word."),
        Principle(title: "Avoid the root fallacy", detail: "A word's origin isn't its “real” meaning. Greek dunamis gave English “dynamite,” but Paul wasn't thinking of explosives."),
        Principle(title: "Check the sources", detail: "Every verse here is quoted exactly from the Berean Standard Bible, and every Hebrew and Greek word is checked against Strong's Concordance and the Berean interlinear to confirm it appears in that verse."),
        Principle(title: "Say how sure we are", detail: "When a derivation is traditional or debated, we attribute it (for example, “Strong's links…”) instead of stating it as settled fact."),
        Principle(title: "Let truth heal", detail: "The goal of word study isn't trivia — it's understanding God's Word more truly, so that truth can renew the mind (Romans 12:2)."),
    ]

    var body: some View {
        List {
            ForEach(principles) { principle in
                VStack(alignment: .leading, spacing: 6) {
                    Text(principle.title).font(.headline)
                    Text(principle.detail).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("How we study words")
    }
}
