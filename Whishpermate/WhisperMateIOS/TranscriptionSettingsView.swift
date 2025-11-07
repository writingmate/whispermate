import SwiftUI
import WhisperMateShared

struct TranscriptionSettingsView: View {
    @ObservedObject var dictionaryManager: DictionaryManager
    @ObservedObject var toneStyleManager: ToneStyleManager
    @ObservedObject var shortcutManager: ShortcutManager

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Feature", selection: $selectedTab) {
                Text("Dictionary").tag(0)
                Text("Tone & Style").tag(1)
                Text("Shortcuts").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            TabView(selection: $selectedTab) {
                DictionaryView(manager: dictionaryManager)
                    .tag(0)

                ToneStyleView(manager: toneStyleManager)
                    .tag(1)

                ShortcutsView(manager: shortcutManager)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Transcription Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dictionary View

struct DictionaryView: View {
    @ObservedObject var manager: DictionaryManager
    @State private var newTrigger = ""
    @State private var newReplacement = ""
    @State private var editingEntry: DictionaryEntry?

    var body: some View {
        List {
            Section(header: Text(""), footer: Text("")) {
                ForEach(manager.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.trigger)
                                .font(.body)
                            Text("→ \(entry.replacement)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { entry.isEnabled },
                            set: { _ in manager.toggleEntry(entry) }
                        ))
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let entry = manager.entries[index]
                        manager.removeEntry(entry)
                    }
                }
            }

            Section(header: Text("Add New Entry"), footer: Text("Dictionary entries help recognize and format specific words correctly")) {
                VStack(spacing: 12) {
                    TextField("Trigger word", text: $newTrigger)
                    TextField("Replacement", text: $newReplacement)

                    if !newTrigger.isEmpty && !newReplacement.isEmpty {
                        Button(action: addEntry) {
                            Label("Add Entry", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private func addEntry() {
        guard !newTrigger.isEmpty && !newReplacement.isEmpty else { return }
        manager.addEntry(trigger: newTrigger, replacement: newReplacement)
        newTrigger = ""
        newReplacement = ""
    }
}

// MARK: - Tone & Style View

struct ToneStyleView: View {
    @ObservedObject var manager: ToneStyleManager
    @State private var showingAddSheet = false

    var body: some View {
        List {
            Section(header: Text(""), footer: Text("")) {
                ForEach(manager.styles) { style in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(style.name)
                                .font(.body.weight(.medium))

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { style.isEnabled },
                                set: { _ in manager.toggleStyle(style) }
                            ))
                        }

                        Text(style.instructions)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !style.appBundleIds.isEmpty {
                            Text("Apps: \(style.appBundleIds.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let style = manager.styles[index]
                        manager.removeStyle(style)
                    }
                }
            }

            Section(header: Text(""), footer: Text("Tone & style rules adjust language formality and structure for different apps")) {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Tone/Style", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddToneStyleSheet(manager: manager, isPresented: $showingAddSheet)
        }
    }
}

struct AddToneStyleSheet: View {
    @ObservedObject var manager: ToneStyleManager
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var appBundleIds = ""
    @State private var instructions = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name"), footer: Text("")) {
                    TextField("e.g., Slack - Professional", text: $name)
                }

                Section(header: Text("App Bundle IDs"), footer: Text("Comma-separated list of app bundle IDs. Leave empty to apply to all apps.")) {
                    TextField("e.g., com.tinyspeck.chatlyio", text: $appBundleIds)
                }

                Section(header: Text("Instructions"), footer: Text("Describe the tone, style, and formatting for this app")) {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Tone/Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addStyle()
                    }
                    .disabled(name.isEmpty || instructions.isEmpty)
                }
            }
        }
    }

    private func addStyle() {
        let bundleIds = appBundleIds
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        manager.addStyle(name: name, appBundleIds: bundleIds, instructions: instructions)
        isPresented = false
    }
}

// MARK: - Shortcuts View

struct ShortcutsView: View {
    @ObservedObject var manager: ShortcutManager
    @State private var newTrigger = ""
    @State private var newExpansion = ""

    var body: some View {
        List {
            Section(header: Text(""), footer: Text("")) {
                ForEach(manager.shortcuts) { shortcut in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shortcut.voiceTrigger)
                                .font(.body)
                            Text("→ \(shortcut.expansion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { shortcut.isEnabled },
                            set: { _ in manager.toggleShortcut(shortcut) }
                        ))
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let shortcut = manager.shortcuts[index]
                        manager.removeShortcut(shortcut)
                    }
                }
            }

            Section(header: Text("Add New Shortcut"), footer: Text("Shortcuts let you say a phrase and have it expand to longer text")) {
                VStack(spacing: 12) {
                    TextField("Voice trigger (e.g., 'my email')", text: $newTrigger)
                    TextField("Expansion text", text: $newExpansion)

                    if !newTrigger.isEmpty && !newExpansion.isEmpty {
                        Button(action: addShortcut) {
                            Label("Add Shortcut", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private func addShortcut() {
        guard !newTrigger.isEmpty && !newExpansion.isEmpty else { return }
        manager.addShortcut(voiceTrigger: newTrigger, expansion: newExpansion)
        newTrigger = ""
        newExpansion = ""
    }
}
