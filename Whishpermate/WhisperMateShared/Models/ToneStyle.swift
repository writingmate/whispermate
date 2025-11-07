import Foundation

public struct ToneStyle: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var appBundleIds: [String]
    public var titlePatterns: [String]  // Window title patterns like "Gmail", "LinkedIn *", etc.
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
