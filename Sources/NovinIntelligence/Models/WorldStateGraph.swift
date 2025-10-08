import Foundation

public final class WorldStateGraph {
    public private(set) var objects: [String: ObjectNode] = [:]
    public private(set) var relations: Set<Relation> = []
    public private(set) var predicates: Set<Predicate> = []

    public init() {}

    public func upsertObject(_ node: ObjectNode) { objects[node.id] = node }
    public func addRelation(_ r: Relation) { relations.insert(r) }
    public func addPredicate(_ p: Predicate) { predicates.insert(p) }

    public func removeRelation(_ r: Relation) { relations.remove(r) }
    public func removePredicate(_ p: Predicate) { predicates.remove(p) }
}
