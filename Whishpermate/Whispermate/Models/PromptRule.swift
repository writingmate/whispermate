import Foundation
internal import Combine

struct PromptRule: Identifiable, Codable {
    let id: UUID
    var text: String
    var isEnabled: Bool

    init(id: UUID = UUID(), text: String, isEnabled: Bool = true) {
        self.id = id
        self.text = text
        self.isEnabled = isEnabled
    }
}

class PromptRulesManager: ObservableObject {
    static let shared = PromptRulesManager()

    @Published var rules: [PromptRule] = []

    private let userDefaultsKey = "prompt_rules"

    private init() {
        loadRules()
    }

    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([PromptRule].self, from: data) {
            rules = decoded
            DebugLog.info("Loaded \(rules.count) prompt rules", context: "PromptRulesManager LOG")
        } else {
            // Add default rules
            rules = [
                PromptRule(text: "Always use numbers for numbers (1, 2, 3) not words"),
                PromptRule(text: "Always translate to English")
            ]
            saveRules()
            DebugLog.info("Created default prompt rules", context: "PromptRulesManager LOG")
        }
    }

    func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            DebugLog.info("Saved \(rules.count) prompt rules", context: "PromptRulesManager LOG")
        }
    }

    func addRule(_ text: String) {
        let rule = PromptRule(text: text)
        rules.append(rule)
        saveRules()
        DebugLog.info("Added rule: \(text)", context: "PromptRulesManager LOG")
    }

    func removeRule(_ rule: PromptRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
        DebugLog.info("Removed rule: \(rule.text)", context: "PromptRulesManager LOG")
    }

    func toggleRule(_ rule: PromptRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isEnabled.toggle()
            saveRules()
            DebugLog.info("Toggled rule: \(rule.text) -> \(rules[index].isEnabled)", context: "PromptRulesManager LOG")
        }
    }

    func updateRule(_ rule: PromptRule, newText: String) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].text = newText
            saveRules()
            DebugLog.info("Updated rule: \(newText)", context: "PromptRulesManager LOG")
        }
    }

    /// Get the combined prompt string from all enabled rules
    var combinedPrompt: String {
        let enabledRules = rules.filter { $0.isEnabled }
        let prompt = enabledRules.map { $0.text }.joined(separator: ". ")
        return prompt.isEmpty ? "" : prompt + "."
    }
}
