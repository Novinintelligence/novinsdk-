import Foundation

public struct Action: Hashable, Codable {
    public let name: String
    public let parameters: [String: String]
    public init(name: String, parameters: [String: String] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}
