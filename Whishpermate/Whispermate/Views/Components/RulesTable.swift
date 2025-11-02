import SwiftUI

struct RulesTable: View {
    @ObservedObject var promptRulesManager: PromptRulesManager
    @Binding var newRuleText: String

    var body: some View {
        VStack(spacing: 0) {
            // Existing rules
            ForEach(Array(promptRulesManager.rules.enumerated()), id: \.element.id) { index, rule in
                RuleRow(
                    rule: rule,
                    onToggle: { promptRulesManager.toggleRule(rule) },
                    onDelete: { promptRulesManager.removeRule(rule) }
                )
            }

            // Inline add row at the bottom
            HStack(spacing: 12) {
                TextField("Add new rule...", text: $newRuleText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        if !newRuleText.isEmpty {
                            promptRulesManager.addRule(newRuleText)
                            newRuleText = ""
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    if !newRuleText.isEmpty {
                        promptRulesManager.addRule(newRuleText)
                        newRuleText = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .opacity(newRuleText.isEmpty ? 0 : 1)
                .padding(.trailing, 26)  // Align with toggle switch position
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
