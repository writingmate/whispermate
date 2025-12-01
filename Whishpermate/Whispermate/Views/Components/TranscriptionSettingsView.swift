import SwiftUI
import WhisperMateShared

struct TranscriptionSettingsView: View {
    @ObservedObject var dictionaryManager: DictionaryManager
    @ObservedObject var contextRulesManager: ContextRulesManager
    @ObservedObject var shortcutManager: ShortcutManager

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Feature", selection: $selectedTab) {
                Text("Dictionary").tag(0)
                Text("Context Rules").tag(1)
                Text("Shortcuts").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 16)

            TabView(selection: $selectedTab) {
                DictionaryTabView(manager: dictionaryManager)
                    .tag(0)

                ContextRulesTabView(manager: contextRulesManager)
                    .tag(1)

                ShortcutsTabView(manager: shortcutManager)
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
    }
}

// MARK: - Dictionary Tab

struct DictionaryTabView: View {
    @ObservedObject var manager: DictionaryManager
    @State private var newTrigger = ""
    @State private var newReplacement = ""

    var body: some View {
        VStack(spacing: 0) {
            // Existing entries
            ForEach(Array(manager.entries.enumerated()), id: \.element.id) { _, entry in
                DictionaryEntryRow(
                    entry: entry,
                    onToggle: { manager.toggleEntry(entry) },
                    onEdit: { trigger, replacement in
                        manager.updateEntry(entry, trigger: trigger, replacement: replacement)
                    },
                    onDelete: { manager.removeEntry(entry) }
                )
            }

            // Add new entry row
            HStack(spacing: 12) {
                TextField("Trigger word", text: $newTrigger)
                    .textFieldStyle(.plain)
                    .dsFont(.label)
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .dsFont(.tiny)
                    .foregroundStyle(.secondary)

                TextField("Replacement (optional)", text: $newReplacement)
                    .textFieldStyle(.plain)
                    .dsFont(.label)
                    .foregroundStyle(newReplacement.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity)

                Button(action: {
                    if !newTrigger.isEmpty {
                        let replacement = newReplacement.isEmpty ? nil : newReplacement
                        manager.addEntry(trigger: newTrigger, replacement: replacement)
                        newTrigger = ""
                        newReplacement = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(Color.dsSecondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(newTrigger.isEmpty ? 0 : 1)
                .padding(.trailing, 26)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.quaternarySystemFill)
        }
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium))
    }
}

struct DictionaryEntryRow: View {
    let entry: DictionaryEntry
    let onToggle: () -> Void
    let onEdit: (String, String?) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editTrigger = ""
    @State private var editReplacement = ""

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                TextField("Trigger", text: $editTrigger)
                    .textFieldStyle(.plain)
                    .dsFont(.label)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .dsFont(.tiny)
                    .foregroundStyle(.tertiary)

                TextField("Replacement (optional)", text: $editReplacement)
                    .textFieldStyle(.plain)
                    .dsFont(.label)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    let replacement = editReplacement.isEmpty ? nil : editReplacement
                    onEdit(editTrigger, replacement)
                    isEditing = false
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .disabled(editTrigger.isEmpty)

                Button(action: {
                    isEditing = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)

                Toggle("", isOn: Binding(
                    get: { entry.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            } else {
                Text(entry.trigger)
                    .dsFont(.label)
                    .foregroundStyle(entry.isEnabled ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .dsFont(.tiny)
                    .foregroundStyle(.tertiary)

                if let replacement = entry.replacement {
                    Text(replacement)
                        .dsFont(.label)
                        .foregroundStyle(entry.isEnabled ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("(no replacement)")
                        .dsFont(.tiny)
                        .foregroundStyle(.tertiary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: {
                    editTrigger = entry.trigger
                    editReplacement = entry.replacement ?? ""
                    isEditing = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Toggle("", isOn: Binding(
                    get: { entry.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.quaternarySystemFill)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.horizontal, 16)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Context Rules Tab

struct ContextRulesTabView: View {
    @ObservedObject var manager: ContextRulesManager
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Existing rules
            ForEach(Array(manager.rules.enumerated()), id: \.element.id) { _, rule in
                ContextRuleRow(
                    rule: rule,
                    onToggle: { manager.toggleRule(rule) },
                    onEdit: { name, bundleIds, titlePatterns, instructions in
                        manager.updateRule(rule, name: name, appBundleIds: bundleIds, titlePatterns: titlePatterns, instructions: instructions)
                    },
                    onDelete: { manager.removeRule(rule) }
                )
            }

            // Add new rule button
            Button(action: { showingAddSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(Color(nsColor: .systemGreen))
                    Text("Add Context Rule")
                        .dsFont(.label)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.quaternarySystemFill)
        }
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium))
        .sheet(isPresented: $showingAddSheet) {
            AddContextRuleSheet(manager: manager, isPresented: $showingAddSheet)
        }
    }
}

// MARK: - App Token Field

struct AppTokenField: View {
    @Binding var selectedAppBundleIds: Set<String>
    let installedApps: [InstalledApp]

    @State private var searchText = ""
    @State private var isShowingDropdown = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Token field area with selected apps
            VStack(spacing: 0) {
                // Selected apps as tokens
                if !selectedApps.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(selectedApps) { app in
                            AppToken(app: app) {
                                selectedAppBundleIds.remove(app.bundleID)
                            }
                        }
                    }
                    .padding(8)
                }

                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .dsFont(.tiny)

                    TextField("Search apps to add...", text: $searchText)
                        .textFieldStyle(.plain)
                        .dsFont(.small)
                        .focused($isSearchFocused)
                        .onSubmit {
                            if let firstMatch = filteredApps.first {
                                selectedAppBundleIds.insert(firstMatch.bundleID)
                                searchText = ""
                            }
                        }
                }
                .padding(8)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSearchFocused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSearchFocused ? 2 : 1)
            )
            .onTapGesture {
                isSearchFocused = true
            }

            // Dropdown with filtered results
            if isSearchFocused && !searchText.isEmpty && !filteredApps.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredApps.prefix(10)) { app in
                            Button(action: {
                                selectedAppBundleIds.insert(app.bundleID)
                                searchText = ""
                            }) {
                                HStack(spacing: 8) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    }
                                    Text(app.name)
                                        .dsFont(.small)
                                    Spacer()
                                    if selectedAppBundleIds.contains(app.bundleID) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.secondary)
                                            .dsFont(.micro)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color(nsColor: .controlBackgroundColor)
                                    .opacity(0.001)
                            )
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 200)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }

            Text("Leave empty to apply to all apps • \(selectedAppBundleIds.count) selected")
                .dsFont(.micro)
                .foregroundStyle(.secondary)
        }
    }

    private var selectedApps: [InstalledApp] {
        installedApps.filter { selectedAppBundleIds.contains($0.bundleID) }
    }

    private var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return []
        }
        return installedApps.filter { app in
            !selectedAppBundleIds.contains(app.bundleID) &&
                (app.name.localizedCaseInsensitiveContains(searchText) ||
                    app.bundleID.localizedCaseInsensitiveContains(searchText))
        }
    }
}

struct AppToken: View {
    let app: InstalledApp
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            Text(app.name)
                .dsFont(.tiny)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .dsFont(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(nsColor: .selectedControlColor).opacity(0.3))
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Title Pattern Token Field

struct TitlePatternTokenField: View {
    @Binding var titlePatterns: [String]
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Tokens and input field
            if !titlePatterns.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(titlePatterns, id: \.self) { pattern in
                        TitlePatternToken(pattern: pattern) {
                            titlePatterns.removeAll { $0 == pattern }
                        }
                    }
                }
                .padding(8)
            }

            // Input field
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.secondary)
                    .dsFont(.tiny)

                TextField("Type pattern and press Enter (e.g., Gmail, *LinkedIn*)", text: $inputText)
                    .textFieldStyle(.plain)
                    .dsFont(.small)
                    .focused($isInputFocused)
                    .onSubmit {
                        addPattern()
                    }
            }
            .padding(8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isInputFocused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isInputFocused ? 2 : 1)
        )
        .onTapGesture {
            isInputFocused = true
        }
    }

    private func addPattern() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !titlePatterns.contains(trimmed) else {
            inputText = ""
            return
        }
        titlePatterns.append(trimmed)
        inputText = ""
    }
}

struct TitlePatternToken: View {
    let pattern: String
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "text.alignleft")
                .dsFont(.micro)
                .foregroundStyle(.secondary)

            Text(pattern)
                .dsFont(.tiny)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .dsFont(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(nsColor: .selectedControlColor).opacity(0.3))
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// Flow layout for tokens
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

struct ContextRuleRow: View {
    let rule: ContextRule
    let onToggle: () -> Void
    let onEdit: (String, [String], [String], String) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var showingEditSheet = false
    @State private var appIcons: [InstalledApp] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .dsFont(.labelMedium)
                        .foregroundStyle(rule.isEnabled ? .primary : .secondary)

                    Text(rule.instructions)
                        .dsFont(.tiny)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if rule.appBundleIds.isEmpty {
                        Text("Applies to all apps")
                            .dsFont(.micro)
                            .foregroundStyle(.secondary)
                            .italic()
                    } else if !appIcons.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(appIcons.prefix(8)) { app in
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                }
                            }
                            if appIcons.count > 8 {
                                Text("+\(appIcons.count - 8)")
                                    .dsFont(.micro)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Spacer()

                Button(action: { showingEditSheet = true }) {
                    Image(systemName: "pencil.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.quaternarySystemFill)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.horizontal, 16)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onAppear {
            loadAppIcons()
        }
        .onChange(of: rule.appBundleIds) { _ in
            loadAppIcons()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditContextRuleSheet(
                rule: rule,
                onSave: onEdit,
                isPresented: $showingEditSheet
            )
        }
    }

    private func loadAppIcons() {
        let installedApps = AppDiscoveryManager.shared.getInstalledApps()
        appIcons = installedApps.filter { app in
            rule.appBundleIds.contains(app.bundleID)
        }
    }
}

struct EditContextRuleSheet: View {
    let rule: ContextRule
    let onSave: (String, [String], [String], String) -> Void
    @Binding var isPresented: Bool

    @State private var name: String
    @State private var selectedAppBundleIds: Set<String>
    @State private var titlePatterns: [String] // Array of window title patterns
    @State private var instructions: String
    @State private var installedApps: [InstalledApp] = []

    init(rule: ContextRule, onSave: @escaping (String, [String], [String], String) -> Void, isPresented: Binding<Bool>) {
        self.rule = rule
        self.onSave = onSave
        _isPresented = isPresented
        _name = State(initialValue: rule.name)
        _selectedAppBundleIds = State(initialValue: Set(rule.appBundleIds))
        _titlePatterns = State(initialValue: rule.titlePatterns)
        _instructions = State(initialValue: rule.instructions)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Context Rule")
                .dsFont(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .dsFont(.smallMedium)
                TextField("e.g., Professional Work Chat", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Apps")
                    .dsFont(.smallMedium)

                AppTokenField(selectedAppBundleIds: $selectedAppBundleIds, installedApps: installedApps)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Window Title Patterns")
                    .dsFont(.smallMedium)

                TitlePatternTokenField(titlePatterns: $titlePatterns)

                Text("Leave empty to match all window titles")
                    .dsFont(.micro)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions")
                    .dsFont(.smallMedium)
                TextEditor(text: $instructions)
                    .dsFont(.small)
                    .frame(height: 80)
                    .border(Color(nsColor: .separatorColor))
                Text("Describe the formatting rules for this context")
                    .dsFont(.micro)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || instructions.isEmpty)
            }
        }
        .padding()
        .frame(width: 450)
        .onAppear {
            installedApps = AppDiscoveryManager.shared.getInstalledApps()
        }
    }

    private func saveRule() {
        onSave(name, Array(selectedAppBundleIds), titlePatterns, instructions)
        isPresented = false
    }
}

struct AddContextRuleSheet: View {
    @ObservedObject var manager: ContextRulesManager
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var selectedAppBundleIds: Set<String> = []
    @State private var titlePatterns: [String] = [] // Array of window title patterns
    @State private var instructions = ""
    @State private var installedApps: [InstalledApp] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Context Rule")
                .dsFont(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .dsFont(.smallMedium)
                TextField("e.g., Professional Work Chat", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Apps")
                    .dsFont(.smallMedium)

                AppTokenField(selectedAppBundleIds: $selectedAppBundleIds, installedApps: installedApps)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Window Title Patterns")
                    .dsFont(.smallMedium)

                TitlePatternTokenField(titlePatterns: $titlePatterns)

                Text("Leave empty to match all window titles")
                    .dsFont(.micro)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions")
                    .dsFont(.smallMedium)
                TextEditor(text: $instructions)
                    .dsFont(.small)
                    .frame(height: 80)
                    .border(Color(nsColor: .separatorColor))
                Text("Describe the formatting rules for this context")
                    .dsFont(.micro)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    addRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || instructions.isEmpty)
            }
        }
        .padding()
        .frame(width: 450)
        .onAppear {
            installedApps = AppDiscoveryManager.shared.getInstalledApps()
        }
    }

    private func addRule() {
        manager.addRule(name: name, appBundleIds: Array(selectedAppBundleIds), titlePatterns: titlePatterns, instructions: instructions)
        isPresented = false
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsTabView: View {
    @ObservedObject var manager: ShortcutManager
    @State private var newTrigger = ""
    @State private var newExpansion = ""

    var body: some View {
        VStack(spacing: 0) {
            // Existing shortcuts
            ForEach(Array(manager.shortcuts.enumerated()), id: \.element.id) { _, shortcut in
                ShortcutRow(
                    shortcut: shortcut,
                    onToggle: { manager.toggleShortcut(shortcut) },
                    onEdit: { voiceTrigger, expansion in
                        manager.updateShortcut(shortcut, voiceTrigger: voiceTrigger, expansion: expansion)
                    },
                    onDelete: { manager.removeShortcut(shortcut) }
                )
            }

            // Add new shortcut row
            HStack(spacing: 12) {
                TextField("Voice trigger (e.g., 'my email')", text: $newTrigger)
                    .textFieldStyle(.plain)
                    .dsFont(.label)
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .dsFont(.tiny)
                    .foregroundStyle(.secondary)

                TextField("Expansion text", text: $newExpansion)
                    .textFieldStyle(.plain)
                    .dsFont(.label)
                    .frame(maxWidth: .infinity)

                Button(action: {
                    if !newTrigger.isEmpty, !newExpansion.isEmpty {
                        manager.addShortcut(voiceTrigger: newTrigger, expansion: newExpansion)
                        newTrigger = ""
                        newExpansion = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(Color(nsColor: .systemGreen))
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(newTrigger.isEmpty || newExpansion.isEmpty ? 0 : 1)
                .padding(.trailing, 26)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.quaternarySystemFill)
        }
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium))
    }
}

struct ShortcutRow: View {
    let shortcut: Shortcut
    let onToggle: () -> Void
    let onEdit: (String, String) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editTrigger = ""
    @State private var editExpansion = ""

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                TextField("Voice trigger", text: $editTrigger)
                    .textFieldStyle(.plain)
                    .dsFont(.label)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .dsFont(.tiny)
                    .foregroundStyle(.tertiary)

                TextField("Expansion", text: $editExpansion)
                    .textFieldStyle(.plain)
                    .dsFont(.label)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    onEdit(editTrigger, editExpansion)
                    isEditing = false
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .disabled(editTrigger.isEmpty || editExpansion.isEmpty)

                Button(action: {
                    isEditing = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)

                Toggle("", isOn: Binding(
                    get: { shortcut.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            } else {
                Text(shortcut.voiceTrigger)
                    .dsFont(.label)
                    .foregroundStyle(shortcut.isEnabled ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .dsFont(.tiny)
                    .foregroundStyle(.tertiary)

                Text(shortcut.expansion)
                    .dsFont(.label)
                    .foregroundStyle(shortcut.isEnabled ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)

                Button(action: {
                    editTrigger = shortcut.voiceTrigger
                    editExpansion = shortcut.expansion
                    isEditing = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .dsFont(.body)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Toggle("", isOn: Binding(
                    get: { shortcut.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.quaternarySystemFill)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.horizontal, 16)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
