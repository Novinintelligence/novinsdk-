import Foundation

public struct ObjectNode: Hashable, Codable {
    public let id: String
    public var type: String
    public var attributes: [String: Double] // numeric features
    public var tags: Set<String>            // symbolic tags/affordances

    public init(id: String, type: String, attributes: [String: Double] = [:], tags: Set<String> = []) {
        self.id = id
        self.type = type
        self.attributes = attributes
        self.tags = tags
    }
}
