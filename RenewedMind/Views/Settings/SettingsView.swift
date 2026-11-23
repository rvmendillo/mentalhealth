import SwiftUI
import RenewedMindKit

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var reminderOn = false
    @State private var reminderTime = Date()
    @State private var apiKey = ""
    @State private var confirmingDelete = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("First name", text: $name)
                        .textContentType(.givenName)
                        .onSubmit { model.setName(name) }
                        .accessibilityIdentifier("settings.name")
                }

                Section {
                    Toggle("Daily affirmation", isOn: $reminderOn)
                        .accessibilityIdentifier("settings.reminderToggle")
                    if reminderOn {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("A gentle notification with each day's affirmation.")
                }

                aiSection

                Section("Help") {
                    NavigationLink {
                        CrisisResourcesList().navigationTitle("Get help now")
                    } label: {
                        Label("Crisis and support lines", systemImage: "heart.text.square")
                    }
                }

                Section("About") {
                    NavigationLink {
                        AboutScienceView()
                    } label: {
                        Label("The science behind Renewed Mind", systemImage: "flask")
                    }
                    .accessibilityIdentifier("settings.science")
                    NavigationLink {
                        AboutSourcesView()
                    } label: {
                        Label("Scripture, word studies, and privacy", systemImage: "book.closed")
                    }
                }

                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share my data (JSON)", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            exportURL = model.exportFileURL()
                        } label: {
                            Label("Export my data", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete all my data", systemImage: "trash")
                    }
                    .accessibilityIdentifier("settings.delete")
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Your journal is stored only on this device. Deleting removes everything, including your saved API key.")
                }

                Section {
                    Text("Renewed Mind is a tool for encouragement and growth. It is not a medical device and does not provide diagnosis or treatment. Please seek professional help when you need it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.setName(name)
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.done")
                }
            }
            .onAppear(perform: load)
            .onChange(of: reminderOn) { _, _ in applyReminder() }
            .onChange(of: reminderTime) { _, _ in applyReminder() }
            .confirmationDialog("Delete all data?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    model.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your check-ins, reflections, journal entries, and settings from this device.")
            }
        }
    }

    private var aiSection: some View {
        Section {
            Picker("Reflection guide", selection: Binding(get: { model.data.settings.aiMode }, set: { model.setAIMode($0) })) {
                ForEach(AIMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .accessibilityIdentifier("settings.aiMode")

            Picker("Claude model", selection: Binding(get: { model.data.settings.claudeModel }, set: { model.setClaudeModel($0) })) {
                ForEach(ClaudeModel.allCases) { claude in
                    Text(claude.displayName).tag(claude)
                }
            }
            Text(model.data.settings.claudeModel.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if model.hasClaudeKey {
                LabeledContent("Anthropic API key", value: "Saved in Keychain")
                Button("Remove API key", role: .destructive) { model.removeAPIKey() }
            } else {
                SecureField("Anthropic API key (sk-ant-…)", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("settings.apiKey")
                Button("Save API key") {
                    model.saveAPIKey(apiKey)
                    apiKey = ""
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                    Link("Get an API key from Anthropic", destination: url)
                        .font(.footnote)
                }
            }

            LabeledContent("Apple Intelligence") {
                Text(OnDeviceAI.status.isAvailable ? "Available" : "Unavailable")
                    .foregroundStyle(OnDeviceAI.status.isAvailable ? Palette.teal : .secondary)
            }
            if !OnDeviceAI.status.isAvailable {
                Text(OnDeviceAI.status.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("AI reflection")
        } footer: {
            Text("Automatic uses Claude when you've saved an API key, then Apple's private on-device model, then the built-in offline guide. With Claude, your thought is sent securely to Anthropic to generate a reflection; nothing else from your journal is sent. Safety screening always runs on your device first, and crisis messages are never sent to AI.")
        }
    }

    private func load() {
        name = model.data.profile.name
        reminderOn = model.data.settings.reminderEnabled
        var components = DateComponents()
        components.hour = model.data.settings.reminderHour
        components.minute = model.data.settings.reminderMinute
        reminderTime = Calendar.current.date(from: components) ?? Date()
    }

    private func applyReminder() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = parts.hour ?? 8
        let minute = parts.minute ?? 0
        let settings = model.data.settings
        guard settings.reminderEnabled != reminderOn || settings.reminderHour != hour || settings.reminderMinute != minute else { return }
        Task { await model.setReminder(enabled: reminderOn, hour: hour, minute: minute) }
    }
}

struct AboutScienceView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                Text("Renewed Mind combines Christian faith with methods that have been tested in research. Here is what it draws on, and how.")
                    .font(.subheadline)
            }
            Section("Renewing thoughts (CBT)") {
                Text("The Renew tool uses cognitive restructuring from cognitive behavioral therapy: noticing thinking patterns, examining evidence, and forming a balanced thought. CBT is among the most studied psychological treatments, and faith-adapted CBT has been found effective for depression and anxiety.")
                cite(["beck1979", "burns1980", "hofmann2012", "pearce2015", "koenig2015", "anderson2015"])
            }
            Section("Positive psychology") {
                Text("Practices like Three Good Things, gratitude letters, acts of kindness, savoring, best possible self, and using your strengths have improved well-being in randomized trials and meta-analyses.")
                cite(["seligman2005", "emmons2003", "sin2009", "bolier2013", "carr2021", "curry2018"])
            }
            Section("Whole-person wellness") {
                Text("Body, mind, relationships, and spirit are connected: physical activity, sleep, time in nature, social connection, breathing, and self-compassion all have research support.")
                cite(["singh2023", "noetel2024", "watson2015", "white2019", "holtlunstad2010", "zaccaro2018", "balban2023", "neff2013"])
            }
            Section("The recommendation algorithm") {
                Text("Suggestions blend four ideas: what you said you're facing today, what has helped you before (learned with Thompson sampling, a Bayesian method, starting from each practice's strength of evidence), variety to avoid hedonic adaptation, and balance across wellness dimensions.")
                cite(["thompson1933", "russo2018", "lyubomirsky2013", "sheldon2012", "lyubomirsky2005"])
            }
            Section("Measuring well-being") {
                Text("The WHO-5 Well-Being Index is a validated five-item questionnaire. Scores of 50 or below suggest low well-being; 28 or below is often associated with depression. It is a screening aid, not a diagnosis.")
                cite(["topp2015"])
            }
            Section("All references") {
                ForEach(model.library.citations) { citation in
                    CitationRow(citation: citation)
                }
            }
        }
        .navigationTitle("The science")
    }

    @ViewBuilder
    private func cite(_ ids: [String]) -> some View {
        let names = ids.compactMap { model.library.citation(id: $0)?.short }
        Text(names.joined(separator: "; "))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct AboutSourcesView: View {
    var body: some View {
        List {
            Section("Scripture") {
                Text("Scripture quotations are from the Berean Standard Bible (BSB), which has been dedicated to the public domain. Every verse in the app is checked word-for-word against the BSB text.")
            }
            Section("Word studies") {
                Text("Hebrew and Greek words come from Strong's Exhaustive Concordance (public domain) and are checked against the Berean interlinear tables to confirm each word appears in its verse. Meanings are summarized carefully, and debated derivations are attributed rather than stated as fact.")
            }
            Section("Word origins") {
                Text("English etymologies are summarized from the Online Etymology Dictionary and Wiktionary, avoiding popular myths.")
            }
            Section("Privacy") {
                Text("Your journal, check-ins, and settings are stored only on this device, protected by iOS data protection. Your API key is stored in the iOS Keychain. Renewed Mind has no accounts, ads, or analytics.")
                Text("When you choose Claude, the thought you are reflecting on is sent to Anthropic over an encrypted connection to generate a response. Apple Intelligence reflections run entirely on your device.")
            }
        }
        .navigationTitle("Sources & privacy")
    }
}
