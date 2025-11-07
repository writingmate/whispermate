import Foundation

public struct DictionaryEntry: Identifiable, Codable {
    public let id: UUID
    public var trigger: String
    public var replacement: String?
    public var isEnabled: Bool

    public init(id: UUID = UUID(), trigger: String, replacement: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = isEnabled
    }
}
