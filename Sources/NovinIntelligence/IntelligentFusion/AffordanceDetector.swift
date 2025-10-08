import Foundation

/// Detects affordances from objects and features using deterministic rules
public final class AffordanceDetector {
    public struct Affordance: Hashable, Codable { public let name: String }

    public init() {}

    public func detect(for object: ObjectNode) -> Set<Affordance> {
        var result: Set<Affordance> = []
        // Example physical-like rules (can be mapped from features):
        if let size = object.attributes["size"], size < 1.0,
           object.tags.contains("convex") {
            result.insert(Affordance(name: "graspable"))
        }
        if object.tags.contains("movable"), object.tags.contains("reachable") {
            result.insert(Affordance(name: "pushable"))
        }
        if object.tags.contains("flat_top") && object.tags.contains("stable_base") {
            result.insert(Affordance(name: "stackable"))
        }
        if object.tags.contains("has_cavity") {
            result.insert(Affordance(name: "containable"))
        }
        return result
    }
}
