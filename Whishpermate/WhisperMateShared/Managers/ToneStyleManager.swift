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

    public func addStyle(name: String, appBundleIds: [String], titlePatterns: [String] = [], instructions: String) {
        // Remove these apps from other styles to ensure mutual exclusivity
        removeAppsFromOtherStyles(appBundleIds: appBundleIds, excludingStyleId: nil)

        let style = ToneStyle(name: name, appBundleIds: appBundleIds, titlePatterns: titlePatterns, instructions: instructions)
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

    public func updateStyle(_ style: ToneStyle, name: String, appBundleIds: [String], titlePatterns: [String] = [], instructions: String) {
        if let index = styles.firstIndex(where: { $0.id == style.id }) {
            // Remove these apps from other styles to ensure mutual exclusivity
            removeAppsFromOtherStyles(appBundleIds: appBundleIds, excludingStyleId: style.id)

            styles[index].name = name
            styles[index].appBundleIds = appBundleIds
            styles[index].titlePatterns = titlePatterns
            styles[index].instructions = instructions
            saveStyles()
            DebugLog.info("Updated style: \(name)", context: "ToneStyleManager")
        }
    }

    /// Get tone/style instructions for a specific app bundle ID and window title
    /// Returns instructions from all matching styles:
    /// - Styles with empty appBundleIds and empty titlePatterns (apply to all)
    /// - Styles that match the app's bundle ID OR the window title pattern (OR logic)
    public func instructions(for appBundleId: String?, windowTitle: String? = nil) -> String? {
        DebugLog.info("=== Checking tone/style rules ===", context: "ToneStyleManager")
        DebugLog.info("App Bundle ID: '\(appBundleId ?? "none")'", context: "ToneStyleManager")
        DebugLog.info("Window Title: '\(windowTitle ?? "none")'", context: "ToneStyleManager")
        DebugLog.info("Total styles: \(styles.count), Enabled: \(styles.filter { $0.isEnabled }.count)", context: "ToneStyleManager")

        // Find all enabled styles that match
        let matchingStyles = styles.filter { style in
            DebugLog.info("", context: "ToneStyleManager")
            DebugLog.info("Evaluating style: '\(style.name)' (enabled: \(style.isEnabled))", context: "ToneStyleManager")

            guard style.isEnabled else {
                DebugLog.info("  → Skipped (disabled)", context: "ToneStyleManager")
                return false
            }

            // If both appBundleIds and titlePatterns are empty, this style applies to everything
            if style.appBundleIds.isEmpty && style.titlePatterns.isEmpty {
                DebugLog.info("  → Universal style (no app or title restrictions) - MATCHES", context: "ToneStyleManager")
                return true
            }

            var appMatches = false
            var titleMatches = false
            var hasAppRestriction = false
            var hasTitleRestriction = false

            // Check app bundle ID match
            if !style.appBundleIds.isEmpty {
                hasAppRestriction = true
                DebugLog.info("  Checking app bundle IDs: \(style.appBundleIds)", context: "ToneStyleManager")
                if let appBundleId = appBundleId, style.appBundleIds.contains(appBundleId) {
                    appMatches = true
                    DebugLog.info("  → App matches: YES", context: "ToneStyleManager")
                } else {
                    DebugLog.info("  → App matches: NO", context: "ToneStyleManager")
                }
            } else {
                DebugLog.info("  → No app restriction", context: "ToneStyleManager")
            }

            // Check window title pattern match
            if !style.titlePatterns.isEmpty {
                hasTitleRestriction = true
                DebugLog.info("  Checking title patterns: \(style.titlePatterns)", context: "ToneStyleManager")
                if let windowTitle = windowTitle {
                    for pattern in style.titlePatterns {
                        if matchesTitlePattern(title: windowTitle, pattern: pattern) {
                            titleMatches = true
                            DebugLog.info("  → Title matches pattern '\(pattern)': YES", context: "ToneStyleManager")
                            break
                        }
                    }
                    if !titleMatches {
                        DebugLog.info("  → Title matches: NO (no patterns matched)", context: "ToneStyleManager")
                    }
                } else {
                    DebugLog.info("  → Title matches: NO (no window title provided)", context: "ToneStyleManager")
                }
            } else {
                DebugLog.info("  → No title restriction", context: "ToneStyleManager")
            }

            // OR logic: Either app OR title must match (if they have restrictions)
            let finalMatch = appMatches || titleMatches
            DebugLog.info("  Final result: \(finalMatch ? "✓ STYLE MATCHES" : "✗ STYLE DOES NOT MATCH") (app: \(appMatches), title: \(titleMatches)) [OR logic]", context: "ToneStyleManager")
            return finalMatch
        }

        // Return combined instructions
        if matchingStyles.isEmpty {
            DebugLog.info("=== No matching styles found ===", context: "ToneStyleManager")
            return nil
        }

        let styleNames = matchingStyles.map { $0.name }.joined(separator: ", ")
        DebugLog.info("", context: "ToneStyleManager")
        DebugLog.info("=== Matched \(matchingStyles.count) style(s): \(styleNames) ===", context: "ToneStyleManager")

        let instructions = matchingStyles.map { $0.instructions }.joined(separator: ". ")
        DebugLog.info("Combined instructions: \(instructions)", context: "ToneStyleManager")
        return instructions
    }

    /// Match a window title against a pattern
    /// Patterns can be:
    /// - "Gmail" - matches if title contains "Gmail"
    /// - "* - LinkedIn" - wildcard pattern match
    /// - "Inbox (*)" - matches titles with wildcards
    private func matchesTitlePattern(title: String, pattern: String) -> Bool {
        DebugLog.info("Matching title pattern - Title: '\(title)', Pattern: '\(pattern)'", context: "ToneStyleManager")

        // Convert pattern to regex
        // * becomes .* (match any characters)
        // Escape special regex characters except *
        let patternRegex = pattern
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "+", with: "\\+")
            .replacingOccurrences(of: "?", with: "\\?")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "^", with: "\\^")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "*", with: ".*")

        DebugLog.info("Converted to regex pattern: '\(patternRegex)'", context: "ToneStyleManager")

        guard let regex = try? NSRegularExpression(pattern: patternRegex, options: [.caseInsensitive]) else {
            DebugLog.info("Failed to create regex from pattern", context: "ToneStyleManager")
            return false
        }

        let range = NSRange(title.startIndex..., in: title)
        let matches = regex.firstMatch(in: title, options: [], range: range) != nil

        DebugLog.info("Pattern match result: \(matches ? "✓ MATCHED" : "✗ NO MATCH")", context: "ToneStyleManager")

        return matches
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
