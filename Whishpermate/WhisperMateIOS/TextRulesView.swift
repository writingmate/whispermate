import SwiftUI
import WhisperMateShared

struct TextRulesView: View {
    @ObservedObject var promptRulesManager: PromptRulesManager
    @State private var newRuleText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(promptRulesManager.rules) { rule in
                    HStack {
                        Text(rule.text)
                            .font(.body)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { _ in promptRulesManager.toggleRule(rule) }
                        ))
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let rule = promptRulesManager.rules[index]
                        promptRulesManager.removeRule(rule)
                    }
                }
            }

            Section {
                HStack {
                    TextField("Add new rule...", text: $newRuleText)
                        .onSubmit {
                            addRule()
                        }

                    if !newRuleText.isEmpty {
                        Button(action: addRule) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Text Rules")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addRule() {
        guard !newRuleText.isEmpty else { return }
        promptRulesManager.addRule(newRuleText)
        newRuleText = ""
    }
}
