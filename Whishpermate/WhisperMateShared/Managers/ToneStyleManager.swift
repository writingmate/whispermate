import Foundation
public import Combine

public class ToneStyleManager: ObservableObject {
    public static let shared = ToneStyleManager()

    @Published public var styles: [ToneStyle] = []

    private let userDefaultsKey = "tone_styles"

    public init() {
        loadStyles()
    }

    public func loadStyles() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ToneStyle].self, from: data) {
            styles = decoded
            DebugLog.info("Loaded \(styles.count) tone styles", context: "ToneStyleManager")
        } else {
            // Add default style templates (all disabled by default)
            styles = [
                ToneStyle(
                    name: "Casual Messaging",
                    appBundleIds: ["com.apple.MobileSMS", "com.discord.Discord", "net.whatsapp.WhatsApp"],
                    instructions: "Keep it casual and friendly, use emojis if appropriate, short sentences, very conversational",
                    isEnabled: false
                ),
                ToneStyle(
                    name: "Professional Work Chat",
                    appBundleIds: ["com.tinyspeck.slackmacgap", "com.microsoft.teams2"],
                    instructions: "Friendly but professional tone, proper grammar, conversational but not too casual",
                    isEnabled: false
                ),
                ToneStyle(
                    name: "Business Email",
                    appBundleIds: ["com.apple.mail", "com.microsoft.Outlook"],
                    instructions: "Professional business tone, complete sentences, formal vocabulary, no contractions, include proper greetings",
                    isEnabled: false
                ),
                ToneStyle(
                    name: "Technical Documentation",
                    appBundleIds: ["com.microsoft.Word", "com.apple.Pages", "com.notion.id"],
                    instructions: "Clear and formal technical writing, complete sentences, proper structure, objective tone",
                    isEnabled: false
                ),
                ToneStyle(
                    name: "English Only",
                    appBundleIds: [],
                    instructions: "Always respond in English, regardless of the input language",
                    isEnabled: false
                )
            ]
            saveStyles()
            DebugLog.info("Created default tone styles", context: "ToneStyleManager")
        }
    }

    public func saveStyles() {
        if let encoded = try? JSONEncoder().encode(styles) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            DebugLog.info("Saved \(styles.count) tone styles", context: "ToneStyleManager")
        }
    }

    public func addStyle(name: String, appBundleIds: [String], instructions: String) {
        // Remove these apps from other styles to ensure mutual exclusivity
        removeAppsFromOtherStyles(appBundleIds: appBundleIds, excludingStyleId: nil)

        let style = ToneStyle(name: name, appBundleIds: appBundleIds, instructions: instructions)
        styles.append(style)
        saveStyles()
        DebugLog.info("Added style: \(name)", context: "ToneStyleManager")
    }

    public func removeStyle(_ style: ToneStyle) {
        styles.removeAll { $0.id == style.id }
        saveStyles()
        DebugLog.info("Removed style: \(style.name)", context: "ToneStyleManager")
    }

    public func toggleStyle(_ style: ToneStyle) {
        if let index = styles.firstIndex(where: { $0.id == style.id }) {
            styles[index].isEnabled.toggle()
            saveStyles()
            DebugLog.info("Toggled style: \(style.name) -> \(styles[index].isEnabled)", context: "ToneStyleManager")
        }
    }

    public func updateStyle(_ style: ToneStyle, name: String, appBundleIds: [String], instructions: String) {
        if let index = styles.firstIndex(where: { $0.id == style.id }) {
            // Remove these apps from other styles to ensure mutual exclusivity
            removeAppsFromOtherStyles(appBundleIds: appBundleIds, excludingStyleId: style.id)

            styles[index].name = name
            styles[index].appBundleIds = appBundleIds
            styles[index].instructions = instructions
            saveStyles()
            DebugLog.info("Updated style: \(name)", context: "ToneStyleManager")
        }
    }

    /// Get tone/style instructions for a specific app bundle ID
    public func instructions(for appBundleId: String?) -> String? {
        guard let appBundleId = appBundleId else { return nil }

        // Find the first enabled style that matches the app
        let matchingStyle = styles.first { style in
            style.isEnabled && style.appBundleIds.contains(appBundleId)
        }

        return matchingStyle?.instructions
    }

    /// Get all enabled style instructions as a combined prompt
    public var allInstructions: String {
        let enabledStyles = styles.filter { $0.isEnabled }
        let instructions = enabledStyles.map { "\($0.name): \($0.instructions)" }.joined(separator: ". ")
        return instructions
    }

    /// Remove apps from other styles to ensure mutual exclusivity
    private func removeAppsFromOtherStyles(appBundleIds: [String], excludingStyleId: UUID?) {
        let appBundleSet = Set(appBundleIds)

        for (index, style) in styles.enumerated() {
            // Skip the style we're updating/adding
            if let excludingId = excludingStyleId, style.id == excludingId {
                continue
            }

            // Remove any overlapping apps from this style
            let updatedBundleIds = style.appBundleIds.filter { !appBundleSet.contains($0) }

            // Only update if there were changes
            if updatedBundleIds.count != style.appBundleIds.count {
                styles[index].appBundleIds = updatedBundleIds
                DebugLog.info("Removed \(style.appBundleIds.count - updatedBundleIds.count) app(s) from style: \(style.name)", context: "ToneStyleManager")
            }
        }
    }
}
