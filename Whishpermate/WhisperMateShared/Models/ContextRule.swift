import Foundation

public struct ContextRule: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var appBundleIds: [String]
    public var titlePatterns: [String] // Window title patterns like "Gmail", "LinkedIn *", etc.
    public var instructions: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, appBundleIds: [String], titlePatterns: [String] = [], instructions: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.appBundleIds = appBundleIds
        self.titlePatterns = titlePatterns
        self.instructions = instructions
        self.isEnabled = isEnabled
    }
}

// MARK: - Migration Support

/// Type alias for backward compatibility during migration
public typealias ToneStyle = ContextRule
