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
            .padding(.bottom, 16)

            TabView(selection: $selectedTab) {
                DictionaryTabView(manager: dictionaryManager)
                    .tag(0)

                ToneStyleTabView(manager: toneStyleManager)
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
            ForEach(Array(manager.entries.enumerated()), id: \.element.id) { index, entry in
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
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField("Replacement (optional)", text: $newReplacement)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
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
                        .font(.system(size: 16))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(newTrigger.isEmpty ? 0 : 1)
                .padding(.trailing, 26)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
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
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                TextField("Replacement (optional)", text: $editReplacement)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)

                Spacer()

                Button(action: {
                    let replacement = editReplacement.isEmpty ? nil : editReplacement
                    onEdit(editTrigger, replacement)
                    isEditing = false
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .disabled(editTrigger.isEmpty)

                Button(action: {
                    isEditing = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
            } else {
                Text(entry.trigger)
                    .font(.system(size: 13))
                    .foregroundStyle(entry.isEnabled ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if entry.replacement != nil {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Text(entry.replacement!)
                        .font(.system(size: 13))
                        .foregroundStyle(entry.isEnabled ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("(no replacement)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                Button(action: {
                    editTrigger = entry.trigger
                    editReplacement = entry.replacement ?? ""
                    isEditing = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
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
        .background(
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Tone & Style Tab

struct ToneStyleTabView: View {
    @ObservedObject var manager: ToneStyleManager
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Existing styles
            ForEach(Array(manager.styles.enumerated()), id: \.element.id) { index, style in
                ToneStyleRow(
                    style: style,
                    onToggle: { manager.toggleStyle(style) },
                    onEdit: { name, bundleIds, titlePatterns, instructions in
                        manager.updateStyle(style, name: name, appBundleIds: bundleIds, titlePatterns: titlePatterns, instructions: instructions)
                    },
                    onDelete: { manager.removeStyle(style) }
                )
            }

            // Add new style button
            Button(action: { showingAddSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                    Text("Add Tone/Style")
                        .font(.system(size: 13))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .sheet(isPresented: $showingAddSheet) {
            AddToneStyleSheet(manager: manager, isPresented: $showingAddSheet)
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
                        .font(.system(size: 11))

                    TextField("Search apps to add...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
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
                                        .font(.system(size: 12))
                                    Spacer()
                                    if selectedAppBundleIds.contains(app.bundleID) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 10))
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
                .font(.system(size: 10))
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
                .font(.system(size: 11))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
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
                    .font(.system(size: 11))

                TextField("Type pattern and press Enter (e.g., Gmail, *LinkedIn*)", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
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
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text(pattern)
                .font(.system(size: 11))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
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

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

struct ToneStyleRow: View {
    let style: ToneStyle
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
                    Text(style.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(style.isEnabled ? .primary : .secondary)

                    Text(style.instructions)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if style.appBundleIds.isEmpty {
                        Text("Applies to all apps")
                            .font(.system(size: 10))
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
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Spacer()

                Button(action: { showingEditSheet = true }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Toggle("", isOn: Binding(
                    get: { style.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onAppear {
            loadAppIcons()
        }
        .onChange(of: style.appBundleIds) { _ in
            loadAppIcons()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditToneStyleSheet(
                style: style,
                onSave: onEdit,
                isPresented: $showingEditSheet
            )
        }
    }

    private func loadAppIcons() {
        let installedApps = AppDiscoveryManager.shared.getInstalledApps()
        appIcons = installedApps.filter { app in
            style.appBundleIds.contains(app.bundleID)
        }
    }
}

struct EditToneStyleSheet: View {
    let style: ToneStyle
    let onSave: (String, [String], [String], String) -> Void
    @Binding var isPresented: Bool

    @State private var name: String
    @State private var selectedAppBundleIds: Set<String>
    @State private var titlePatterns: [String]  // Array of window title patterns
    @State private var instructions: String
    @State private var installedApps: [InstalledApp] = []

    init(style: ToneStyle, onSave: @escaping (String, [String], [String], String) -> Void, isPresented: Binding<Bool>) {
        self.style = style
        self.onSave = onSave
        self._isPresented = isPresented
        self._name = State(initialValue: style.name)
        self._selectedAppBundleIds = State(initialValue: Set(style.appBundleIds))
        self._titlePatterns = State(initialValue: style.titlePatterns)
        self._instructions = State(initialValue: style.instructions)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Tone/Style")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                TextField("e.g., Professional Work Chat", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Apps")
                    .font(.system(size: 12, weight: .medium))

                AppTokenField(selectedAppBundleIds: $selectedAppBundleIds, installedApps: installedApps)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Window Title Patterns")
                    .font(.system(size: 12, weight: .medium))

                TitlePatternTokenField(titlePatterns: $titlePatterns)

                Text("Leave empty to match all window titles")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions")
                    .font(.system(size: 12, weight: .medium))
                TextEditor(text: $instructions)
                    .font(.system(size: 12))
                    .frame(height: 80)
                    .border(Color(nsColor: .separatorColor))
                Text("Describe the tone, style, and formatting")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveStyle()
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

    private func saveStyle() {
        onSave(name, Array(selectedAppBundleIds), titlePatterns, instructions)
        isPresented = false
    }
}

struct AddToneStyleSheet: View {
    @ObservedObject var manager: ToneStyleManager
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var selectedAppBundleIds: Set<String> = []
    @State private var titlePatterns: [String] = []  // Array of window title patterns
    @State private var instructions = ""
    @State private var installedApps: [InstalledApp] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Tone/Style")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                TextField("e.g., Professional Work Chat", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Apps")
                    .font(.system(size: 12, weight: .medium))

                AppTokenField(selectedAppBundleIds: $selectedAppBundleIds, installedApps: installedApps)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Window Title Patterns")
                    .font(.system(size: 12, weight: .medium))

                TitlePatternTokenField(titlePatterns: $titlePatterns)

                Text("Leave empty to match all window titles")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions")
                    .font(.system(size: 12, weight: .medium))
                TextEditor(text: $instructions)
                    .font(.system(size: 12))
                    .frame(height: 80)
                    .border(Color(nsColor: .separatorColor))
                Text("Describe the tone, style, and formatting")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    addStyle()
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

    private func addStyle() {
        manager.addStyle(name: name, appBundleIds: Array(selectedAppBundleIds), titlePatterns: titlePatterns, instructions: instructions)
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
            ForEach(Array(manager.shortcuts.enumerated()), id: \.element.id) { index, shortcut in
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
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField("Expansion text", text: $newExpansion)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)

                Button(action: {
                    if !newTrigger.isEmpty && !newExpansion.isEmpty {
                        manager.addShortcut(voiceTrigger: newTrigger, expansion: newExpansion)
                        newTrigger = ""
                        newExpansion = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(newTrigger.isEmpty || newExpansion.isEmpty ? 0 : 1)
                .padding(.trailing, 26)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
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
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                TextField("Expansion", text: $editExpansion)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)

                Spacer()

                Button(action: {
                    onEdit(editTrigger, editExpansion)
                    isEditing = false
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .disabled(editTrigger.isEmpty || editExpansion.isEmpty)

                Button(action: {
                    isEditing = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
            } else {
                Text(shortcut.voiceTrigger)
                    .font(.system(size: 13))
                    .foregroundStyle(shortcut.isEnabled ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                Text(shortcut.expansion)
                    .font(.system(size: 13))
                    .foregroundStyle(shortcut.isEnabled ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    editTrigger = shortcut.voiceTrigger
                    editExpansion = shortcut.expansion
                    isEditing = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(isHovering ? 1 : 0)

                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
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
        .background(
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
