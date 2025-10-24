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
    @Published var rules: [PromptRule] = []

    private let userDefaultsKey = "prompt_rules"

    init() {
        loadRules()
    }

    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([PromptRule].self, from: data) {
            rules = decoded
            print("[PromptRulesManager LOG] Loaded \(rules.count) prompt rules")
        } else {
            // Add default rules
            rules = [
                PromptRule(text: "Always use numbers for numbers (1, 2, 3) not words"),
                PromptRule(text: "Always translate to English")
            ]
            saveRules()
            print("[PromptRulesManager LOG] Created default prompt rules")
        }
    }

    func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("[PromptRulesManager LOG] Saved \(rules.count) prompt rules")
        }
    }

    func addRule(_ text: String) {
        let rule = PromptRule(text: text)
        rules.append(rule)
        saveRules()
        print("[PromptRulesManager LOG] Added rule: \(text)")
    }

    func removeRule(_ rule: PromptRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
        print("[PromptRulesManager LOG] Removed rule: \(rule.text)")
    }

    func toggleRule(_ rule: PromptRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isEnabled.toggle()
            saveRules()
            print("[PromptRulesManager LOG] Toggled rule: \(rule.text) -> \(rules[index].isEnabled)")
        }
    }

    func updateRule(_ rule: PromptRule, newText: String) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].text = newText
            saveRules()
            print("[PromptRulesManager LOG] Updated rule: \(newText)")
        }
    }

    /// Get the combined prompt string from all enabled rules
    var combinedPrompt: String {
        let enabledRules = rules.filter { $0.isEnabled }
        let prompt = enabledRules.map { $0.text }.joined(separator: ". ")
        return prompt.isEmpty ? "" : prompt + "."
    }
}
