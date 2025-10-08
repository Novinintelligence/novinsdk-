import Foundation

public struct Relation: Hashable, Codable {
    public let subject: String
    public let predicate: String
    public let object: String

    public init(_ subject: String, _ predicate: String, _ object: String) {
        self.subject = subject
        self.predicate = predicate
        self.object = object
    }
}
