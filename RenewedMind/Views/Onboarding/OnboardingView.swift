import SwiftUI
import RenewedMindKit

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var page = 0
    @State private var name = ""

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                Group {
                    switch page {
                    case 0: welcome
                    case 1: howItWorks
                    default: beforeWeBegin
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)

                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index == page ? Palette.teal : Palette.teal.opacity(0.25))
                            .frame(width: index == page ? 22 : 8, height: 8)
                    }
                }
                .padding(.bottom, 16)
                .accessibilityHidden(true)

                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        model.completeOnboarding(name: name)
                    }
                } label: {
                    Text(page < 2 ? "Continue" : "I understand — let's begin")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .accessibilityIdentifier(page < 2 ? "onboarding.continue" : "onboarding.begin")
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "sunrise.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.gold)
                .accessibilityHidden(true)
            Text("Renewed Mind")
                .font(.system(.largeTitle, design: .serif).weight(.bold))
            Text("Christ-centered affirmations, healthier thinking, and science-backed practices for your whole self.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let verse = model.library.affirmation(id: "renewal-romans-12-2") {
                VStack(spacing: 6) {
                    Text("“\(verse.verse)”")
                        .font(.system(.body, design: .serif).italic())
                        .multilineTextAlignment(.center)
                    Text(verse.reference)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.gold)
                }
                .padding()
                .background(Palette.verseBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            Spacer()
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("How it works")
                .font(.system(.largeTitle, design: .serif).weight(.bold))
            feature("arrow.triangle.2.circlepath", "Renew your thoughts",
                    "Write down a painful thought. Using cognitive behavioral therapy and Scripture, you'll notice thinking traps and find a truer, kinder perspective.")
            feature("book.closed", "Stand on verified truth",
                    "Every affirmation is anchored in a verse from the Berean Standard Bible, with a careful Hebrew or Greek word study.")
            feature("leaf", "Practice whole-person wellness",
                    "Breath prayer, gratitude, movement, rest, connection, and more — each backed by research and personalized to what helps you.")
            feature("lock.shield", "Private by design",
                    "Your journal stays on this device. AI reflections are optional, and you choose which model to use.")
            Spacer()
        }
    }

    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Palette.teal)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var beforeWeBegin: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("Before we begin")
                .font(.system(.largeTitle, design: .serif).weight(.bold))
            VStack(alignment: .leading, spacing: 8) {
                Text("What should we call you?")
                    .font(.headline)
                TextField("Your first name (optional)", text: $name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .padding(14)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("onboarding.name")
            }
            Card {
                Label("An important note", systemImage: "heart.text.square")
                    .font(.headline)
                    .foregroundStyle(Palette.rose)
                Text("Renewed Mind supports your well-being, but it isn't therapy or medical care, and it can't respond to emergencies.")
                    .font(.subheadline)
                Text("If you are in danger or thinking about suicide, call your local emergency number. In the US, call or text 988 any time. Help is available, and you deserve it.")
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
        }
    }
}
