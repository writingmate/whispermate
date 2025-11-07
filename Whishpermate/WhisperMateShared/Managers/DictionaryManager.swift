import Foundation
public import Combine

public class DictionaryManager: ObservableObject {
    public static let shared = DictionaryManager()

    @Published public var entries: [DictionaryEntry] = []

    private let userDefaultsKey = "dictionary_entries"

    public init() {
        loadEntries()
    }

    public func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: data) {
            entries = decoded
            DebugLog.info("Loaded \(entries.count) dictionary entries", context: "DictionaryManager")
        } else {
            // Add default entries with real-world examples (all disabled by default)
            entries = [
                // Words needing correction (with replacements)
                DictionaryEntry(trigger: "whisper mate", replacement: "WhisperMate", isEnabled: false),
                DictionaryEntry(trigger: "calendly", replacement: "Calendly", isEnabled: false),
                DictionaryEntry(trigger: "open AI", replacement: "OpenAI", isEnabled: false),
                DictionaryEntry(trigger: "chat GPT", replacement: "ChatGPT", isEnabled: false),
                DictionaryEntry(trigger: "git hub", replacement: "GitHub", isEnabled: false),

                // Technical terms (no replacement - just for recognition)
                DictionaryEntry(trigger: "API", replacement: nil, isEnabled: false),
                DictionaryEntry(trigger: "iOS", replacement: nil, isEnabled: false),
                DictionaryEntry(trigger: "macOS", replacement: nil, isEnabled: false),
                DictionaryEntry(trigger: "JSON", replacement: nil, isEnabled: false),
                DictionaryEntry(trigger: "SQL", replacement: nil, isEnabled: false)
            ]
            saveEntries()
            DebugLog.info("Created default dictionary entries with examples", context: "DictionaryManager")
        }
    }

    public func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            DebugLog.info("Saved \(entries.count) dictionary entries", context: "DictionaryManager")
        }
    }

    public func addEntry(trigger: String, replacement: String?) {
        let entry = DictionaryEntry(trigger: trigger, replacement: replacement)
        entries.append(entry)
        saveEntries()
        let logMsg = replacement != nil ? "\(trigger) -> \(replacement!)" : trigger
        DebugLog.info("Added entry: \(logMsg)", context: "DictionaryManager")
    }

    public func removeEntry(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
        DebugLog.info("Removed entry: \(entry.trigger)", context: "DictionaryManager")
    }

    public func toggleEntry(_ entry: DictionaryEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].isEnabled.toggle()
            saveEntries()
            DebugLog.info("Toggled entry: \(entry.trigger) -> \(entries[index].isEnabled)", context: "DictionaryManager")
        }
    }

    public func updateEntry(_ entry: DictionaryEntry, trigger: String, replacement: String?) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].trigger = trigger
            entries[index].replacement = replacement
            saveEntries()
            let logMsg = replacement != nil ? "\(trigger) -> \(replacement!)" : trigger
            DebugLog.info("Updated entry: \(logMsg)", context: "DictionaryManager")
        }
    }

    /// Get transcription hints for Whisper API (comma-separated list of trigger words)
    public var transcriptionHints: String {
        let enabledEntries = entries.filter { $0.isEnabled }
        let hints = enabledEntries.map { $0.trigger }.joined(separator: ", ")
        return hints
    }

    /// Apply dictionary replacements to transcribed text (only for entries with replacements)
    public func applyReplacements(to text: String) -> String {
        var result = text
        let enabledEntries = entries.filter { $0.isEnabled && $0.replacement != nil }

        // Sort by trigger length (longest first) to handle overlapping triggers
        let sortedEntries = enabledEntries.sorted { $0.trigger.count > $1.trigger.count }

        for entry in sortedEntries {
            guard let replacement = entry.replacement else { continue }
            // Case-insensitive replacement
            result = result.replacingOccurrences(
                of: entry.trigger,
                with: replacement,
                options: .caseInsensitive
            )
        }

        return result
    }

    /// Get formatting instructions for LLM to apply dictionary replacements
    public var formattingInstructions: String? {
        let enabledEntries = entries.filter { $0.isEnabled && $0.replacement != nil }
        guard !enabledEntries.isEmpty else { return nil }

        let replacements = enabledEntries.map { "\($0.trigger) → \($0.replacement!)" }.joined(separator: ", ")
        return "Apply these word replacements: \(replacements)"
    }
}
