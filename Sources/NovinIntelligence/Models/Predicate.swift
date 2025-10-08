import Foundation

/// Atomic predicate representation for symbolic reasoning
public struct Predicate: Hashable, Codable {
    public let name: String
    public let arguments: [String]

    public init(_ name: String, _ arguments: [String] = []) {
        self.name = name
        self.arguments = arguments
    }
}

/// Logical constraint expressed as a function over a set of predicates
public struct Constraint: Codable {
    public let description: String
    public init(description: String) { self.description = description }
}
