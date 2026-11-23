import SwiftUI
import RenewedMindKit

/// A verse with its reference, styled for reading.
struct VerseView: View {
    let verse: String
    let reference: String
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verse)
                .font(.system(compact ? .callout : .body, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(reference)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.gold)
                Spacer()
                Text("BSB")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Berean Standard Bible")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.verseBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The Hebrew or Greek word study for an affirmation.
struct WordStudyCard: View {
    let study: WordStudy
    var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(study.lemma)
                    .font(.system(size: 30, weight: .medium, design: .serif))
                    .accessibilityLabel("\(study.language.displayName) word \(study.transliteration)")
                VStack(alignment: .leading, spacing: 2) {
                    Text(study.transliteration)
                        .font(.headline.italic())
                    Text("\(study.language.displayName) · Strong's \(study.strongs)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Translated “\(study.english)”")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.teal)
            Text(study.meaning)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if expanded {
                Text(study.insight)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wordStudy")
    }
}

/// Today's affirmation, verse, and word study.
struct AffirmationCard: View {
    @EnvironmentObject private var model: AppModel
    let affirmation: Affirmation
    var title = "Today's affirmation"

    var body: some View {
        Card {
            HStack {
                SectionLabel(title: title, systemImage: affirmation.theme.symbol, color: affirmation.theme.color)
                Spacer()
                Button {
                    model.toggleFavorite(affirmation.id)
                } label: {
                    Image(systemName: model.isFavorite(affirmation.id) ? "heart.fill" : "heart")
                        .foregroundStyle(Palette.rose)
                }
                .accessibilityLabel(model.isFavorite(affirmation.id) ? "Remove from favorites" : "Add to favorites")
                .accessibilityIdentifier("affirmation.favorite")
                ShareLink(item: "\(affirmation.affirmation)\n\n“\(affirmation.verse)” — \(affirmation.reference) (BSB)") {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share affirmation")
            }
            Text(affirmation.affirmation)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("affirmation.text")
            VerseView(verse: affirmation.verse, reference: affirmation.reference)
            NavigationLink {
                AffirmationDetailView(affirmation: affirmation)
            } label: {
                HStack(spacing: 4) {
                    Text("Word study:")
                        .foregroundStyle(.secondary)
                    Text("\(affirmation.wordStudy.transliteration) (\(affirmation.wordStudy.lemma))")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .font(.subheadline)
            }
            .accessibilityIdentifier("affirmation.wordStudyLink")
        }
    }
}

struct AffirmationDetailView: View {
    @EnvironmentObject private var model: AppModel
    let affirmation: Affirmation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(affirmation.theme.title, systemImage: affirmation.theme.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(affirmation.theme.color)
                Text(affirmation.affirmation)
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                VerseView(verse: affirmation.verse, reference: affirmation.reference)
                Card {
                    SectionLabel(title: "Word study", systemImage: "character.book.closed")
                    WordStudyCard(study: affirmation.wordStudy)
                }
                Card {
                    SectionLabel(title: "Reflect", systemImage: "bubble.left.and.text.bubble.right")
                    Text(affirmation.reflection)
                        .font(.body)
                }
                Text("Scripture: Berean Standard Bible (public domain). Word data: Strong's Exhaustive Concordance, verified against the Berean interlinear.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle(affirmation.reference)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.toggleFavorite(affirmation.id)
                } label: {
                    Image(systemName: model.isFavorite(affirmation.id) ? "heart.fill" : "heart")
                }
                .accessibilityLabel(model.isFavorite(affirmation.id) ? "Remove from favorites" : "Add to favorites")
            }
        }
    }
}
