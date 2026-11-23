import SwiftUI
import RenewedMindKit

/// Immediate help: emergency number, crisis lines, and grounding.
struct CrisisResourcesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var showsDoneButton = true

    var body: some View {
        NavigationStack {
            CrisisResourcesList()
                .navigationTitle("Get help now")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if showsDoneButton {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
                }
        }
    }
}

struct CrisisResourcesList: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let region = model.crisisRegion
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You are not alone.")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                    Text("If you might act on thoughts of harming yourself or someone else, please reach out right now. Talking to someone can help you get through this moment.")
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
                if let url = region.emergencyURL {
                    Link(destination: url) {
                        Label("Call emergency services (\(region.emergencyNumber))", systemImage: "phone.fill")
                            .font(.headline)
                            .foregroundStyle(Palette.rose)
                    }
                    .accessibilityIdentifier("crisis.emergency")
                }
            }
            Section(region.code == "INTL" ? "Find a helpline" : "Crisis lines · \(region.name)") {
                ForEach(region.lines) { line in
                    CrisisLineRow(line: line)
                }
                if region.code != "INTL" {
                    CrisisLineRow(line: CrisisDirectory.findAHelpline)
                }
            }
            Section("Right now, you could") {
                NavigationLink {
                    if let practice = model.library.practice(id: "grounding-54321") {
                        PracticeDetailView(practice: practice)
                    }
                } label: {
                    Label("Try 5-4-3-2-1 grounding", systemImage: "hand.raised")
                }
                Label("Tell someone near you how you feel", systemImage: "person.2")
                Label("Move away from anything you could use to hurt yourself", systemImage: "shield")
            }
            if let verse = model.library.affirmation(id: ReframeEngine.crisisAffirmationID) {
                Section {
                    VerseView(verse: verse.verse, reference: verse.reference)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                Picker("Region", selection: Binding(
                    get: { model.data.settings.regionOverride ?? "" },
                    set: { model.setRegionOverride($0.isEmpty ? nil : $0) }
                )) {
                    Text("Automatic").tag("")
                    ForEach(CrisisDirectory.regions) { r in
                        Text(r.name).tag(r.code)
                    }
                    Text("Other country").tag("INTL")
                }
            } footer: {
                Text("Renewed Mind is not an emergency service. Phone numbers are provided for convenience; if a line doesn't connect, call your local emergency number.")
            }
        }
        .accessibilityIdentifier("crisis.list")
    }
}

struct CrisisLineRow: View {
    let line: CrisisLine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(line.name).font(.headline)
            Text(line.detail).font(.subheadline).foregroundStyle(.secondary)
            FlowLayout(spacing: 10) {
                if let url = line.phoneURL {
                    Link(destination: url) { Label("Call", systemImage: "phone.fill") }
                        .buttonStyle(SecondaryButtonStyle(color: Palette.rose))
                }
                if let url = line.smsURL {
                    Link(destination: url) { Label("Text", systemImage: "message.fill") }
                        .buttonStyle(SecondaryButtonStyle(color: Palette.teal))
                }
                if let url = line.websiteURL {
                    Link(destination: url) { Label("Website", systemImage: "safari") }
                        .buttonStyle(SecondaryButtonStyle(color: .secondary))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// A banner shown on a reframe when safety language was detected.
struct SafetyBanner: View {
    @EnvironmentObject private var model: AppModel
    let level: CrisisLevel
    @State private var showingHelp = false

    var body: some View {
        let region = model.crisisRegion
        VStack(alignment: .leading, spacing: 10) {
            Label(level == .urgent ? "You deserve support right now" : "Support is available",
                  systemImage: "heart.circle.fill")
                .font(.headline)
                .foregroundStyle(.white)
            Text(level == .urgent
                 ? "It sounds like you might be in a lot of pain. Please contact a crisis line or emergency services now, or tell someone you trust."
                 : "If things feel like too much, you don't have to carry them alone. Trained, caring people are ready to listen.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))
            HStack(spacing: 10) {
                if let first = region.lines.first, let url = first.phoneURL ?? first.smsURL ?? first.websiteURL {
                    Link(destination: url) {
                        Text(first.phone.map { "Call \($0)" } ?? "Open \(first.name)")
                            .font(.subheadline.weight(.bold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(.white, in: Capsule())
                            .foregroundStyle(Palette.rose)
                    }
                    .accessibilityIdentifier("safety.primaryLine")
                }
                Button("More options") { showingHelp = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("safety.moreOptions")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.rose, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("safety.banner")
        .sheet(isPresented: $showingHelp) {
            CrisisResourcesView().environmentObject(model)
        }
    }
}
