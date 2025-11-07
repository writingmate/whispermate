import Foundation

public struct Shortcut: Identifiable, Codable {
    public let id: UUID
    public var voiceTrigger: String
    public var expansion: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), voiceTrigger: String, expansion: String, isEnabled: Bool = true) {
        self.id = id
        self.voiceTrigger = voiceTrigger
        self.expansion = expansion
        self.isEnabled = isEnabled
    }
}
