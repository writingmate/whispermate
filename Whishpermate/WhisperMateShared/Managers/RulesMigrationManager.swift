import Foundation

public class RulesMigrationManager {
    private static let migrationKey = "rules_migrated_to_v2"

    /// Migrate old prompt rules to new structured system
    public static func migrateIfNeeded() {
        // Check if migration already completed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            DebugLog.info("Rules already migrated, skipping", context: "RulesMigrationManager")
            return
        }

        DebugLog.info("Starting rules migration", context: "RulesMigrationManager")

        // Try to load old prompt rules
        let oldRulesKey = "prompt_rules"
        guard let data = UserDefaults.standard.data(forKey: oldRulesKey),
              let oldRules = try? JSONDecoder().decode([PromptRule].self, from: data),
              !oldRules.isEmpty else {
            DebugLog.info("No old rules found to migrate", context: "RulesMigrationManager")
            markMigrationComplete()
            return
        }

        DebugLog.info("Found \(oldRules.count) old rules to migrate", context: "RulesMigrationManager")

        // Categorize and migrate rules
        migrateRulesToNewSystem(oldRules)

        // Delete old rules
        UserDefaults.standard.removeObject(forKey: oldRulesKey)

        // Mark migration as complete
        markMigrationComplete()

        DebugLog.info("Rules migration completed successfully", context: "RulesMigrationManager")
    }

    private static func migrateRulesToNewSystem(_ oldRules: [PromptRule]) {
        let dictionaryManager = DictionaryManager.shared
        let toneStyleManager = ToneStyleManager.shared
        let shortcutManager = ShortcutManager.shared

        for rule in oldRules where rule.isEnabled {
            let text = rule.text.lowercased()

            // Detect shortcuts (contains "my " or "insert" or "->")
            if text.contains("my ") || text.contains("insert") || text.contains("->") {
                // Try to extract shortcut pattern
                if let shortcut = extractShortcut(from: rule.text) {
                    shortcutManager.shortcuts.append(shortcut)
                    DebugLog.info("Migrated as shortcut: \(rule.text)", context: "RulesMigrationManager")
                    continue
                }
            }

            // Detect dictionary entries (specific words/terms)
            if isDictionaryEntry(text) {
                if let entry = extractDictionaryEntry(from: rule.text) {
                    dictionaryManager.entries.append(entry)
                    DebugLog.info("Migrated as dictionary entry: \(rule.text)", context: "RulesMigrationManager")
                    continue
                }
            }

            // Default: migrate as tone/style instruction
            let style = ToneStyle(
                name: "Migrated Rule",
                appBundleIds: [], // Universal (applies to all apps)
                instructions: rule.text,
                isEnabled: true
            )
            toneStyleManager.styles.append(style)
            DebugLog.info("Migrated as tone/style: \(rule.text)", context: "RulesMigrationManager")
        }

        // Save all managers
        dictionaryManager.saveEntries()
        toneStyleManager.saveStyles()
        shortcutManager.saveShortcuts()
    }

    private static func isDictionaryEntry(_ text: String) -> Bool {
        // Short rules with simple patterns are likely dictionary entries
        let words = text.split(separator: " ")
        return words.count <= 5 && !text.contains("always") && !text.contains("use")
    }

    private static func extractShortcut(from text: String) -> Shortcut? {
        // Simple heuristic: if contains "my X" pattern
        if let myRange = text.range(of: "my ", options: .caseInsensitive) {
            let afterMy = text[myRange.upperBound...]
            let trigger = "my \(afterMy.split(separator: " ").first ?? "")"
            return Shortcut(
                voiceTrigger: trigger,
                expansion: "[Edit expansion in settings]",
                isEnabled: true
            )
        }
        return nil
    }

    private static func extractDictionaryEntry(from text: String) -> DictionaryEntry? {
        // If text is short and simple, treat as dictionary entry
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.split(separator: " ").count <= 3 {
            return DictionaryEntry(
                trigger: trimmed,
                replacement: trimmed,
                isEnabled: true
            )
        }
        return nil
    }

    private static func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// Reset migration flag (for testing only)
    public static func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        DebugLog.info("Migration flag reset", context: "RulesMigrationManager")
    }
}
