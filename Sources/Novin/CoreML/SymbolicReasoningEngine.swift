import Foundation

/// Training-free symbolic reasoning engine (stub for Phase 1)
/// Provides A* and ToT-lite hooks; integrates safety heuristics when enabled via config.
public final class SymbolicReasoningEngine {
    public struct HeuristicWeights {
        public var goal: Double = 1.0
        public var threat: Double = 1.0
        public var normality: Double = 1.0
        public init() {}
    }

    public init() {}

    /// Compute a plan from world state to a goal description using A* (placeholder)
    public func plan(initial: WorldStateGraph,
                     goalDescription: [Predicate],
                     constraints: [Constraint] = [],
                     heuristic: ((WorldStateGraph) -> Double)? = nil,
                     maxNodes: Int = 256) -> Plan {
        // Define a minimal symbolic pipeline with stage operators
        // Stages: observe -> analyze -> decide -> act
        // Represented as predicates: stage_observe, stage_analyze, stage_decide, stage_act

        struct Operator {
            let name: String
            let precond: (WorldStateGraph) -> Bool
            let apply: (WorldStateGraph) -> WorldStateGraph
            let cost: Double
        }

        // Build operators
        let ops: [Operator] = [
            Operator(
                name: "observe",
                precond: { g in g.predicates.contains(Predicate("stage_observe")) },
                apply: { g in let ng = g.copy(); ng.removePredicate(Predicate("stage_observe")); ng.addPredicate(Predicate("stage_analyze")); return ng },
                cost: 1.0
            ),
            Operator(
                name: "analyze",
                precond: { g in g.predicates.contains(Predicate("stage_analyze")) },
                apply: { g in let ng = g.copy(); ng.removePredicate(Predicate("stage_analyze")); ng.addPredicate(Predicate("stage_decide")); return ng },
                cost: 1.0
            ),
            Operator(
                name: "decide",
                precond: { g in g.predicates.contains(Predicate("stage_decide")) },
                apply: { g in let ng = g.copy(); ng.removePredicate(Predicate("stage_decide")); ng.addPredicate(Predicate("stage_act")); return ng },
                cost: 1.0
            )
        ]

        // Ensure initial has a stage
        let start = initial.ensureStage()
        let goalPreds: Set<Predicate> = goalDescription.isEmpty ? [Predicate("stage_act")] : Set(goalDescription)

        // A* over tiny state space; use simple arrays for open set
        typealias Node = (g: WorldStateGraph, gCost: Double, fCost: Double, path: [Action])

        var open: [Node] = []
        var best: [String: Double] = [:]

        func isGoal(_ g: WorldStateGraph) -> Bool {
            for p in goalPreds { if !g.predicates.contains(p) { return false } }
            return true
        }

        func h(_ g: WorldStateGraph) -> Double {
            if let hf = heuristic { return max(0.0, hf(g)) }
            // Default heuristic: remaining stage distance
            if g.predicates.contains(Predicate("stage_act")) { return 0 }
            if g.predicates.contains(Predicate("stage_decide")) { return 1 }
            if g.predicates.contains(Predicate("stage_analyze")) { return 2 }
            return 3
        }

        let startKey = start.stateKey()
        open.append((g: start, gCost: 0.0, fCost: h(start), path: []))
        best[startKey] = 0.0

        var nodesExpanded = 0
        while !open.isEmpty && nodesExpanded < maxNodes {
            // Pop node with minimal fCost
            var idx = 0
            for i in 1..<open.count { if open[i].fCost < open[idx].fCost { idx = i } }
            let current = open.remove(at: idx)
            nodesExpanded += 1

            if isGoal(current.g) {
                return Plan(steps: current.path, estimatedCost: current.gCost)
            }

            for op in ops {
                if op.precond(current.g) {
                    let nextG = op.apply(current.g)
                    let newCost = current.gCost + op.cost
                    let key = nextG.stateKey()
                    if let prev = best[key], prev <= newCost { continue }
                    best[key] = newCost
                    let f = newCost + h(nextG)
                    let newPath = current.path + [Action(name: op.name)]
                    open.append((g: nextG, gCost: newCost, fCost: f, path: newPath))
                }
            }
        }

        // Failed to find goal within cap; return best-so-far (possibly empty)
        // Choose lowest fCost path among explored nodes if any
        if let bestNode = open.min(by: { $0.fCost < $1.fCost }) {
            return Plan(steps: bestNode.path, estimatedCost: bestNode.gCost)
        }
        return Plan(steps: [], estimatedCost: 0.0)
    }

    /// Optional multi-branch exploration (Tree-of-Thoughts lite)
    public func explore(initial: WorldStateGraph,
                        goalDescription: [Predicate],
                        branchFactor: Int = 3,
                        depthLimit: Int = 6) -> [Plan] {
        // For brevity, delegate to plan() from varying initial heuristics
        // This returns up to 'branchFactor' diverse plans by nudging heuristic
        var plans: [Plan] = []
        for i in 0..<branchFactor {
            let bias = Double(i) * 0.1
            let p = plan(initial: initial, goalDescription: goalDescription, heuristic: { _ in bias }, maxNodes: depthLimit * 64)
            plans.append(p)
        }
        return plans
    }
}

// MARK: - World helpers
private extension WorldStateGraph {
    func copy() -> WorldStateGraph {
        let g = WorldStateGraph()
        for (_, o) in self.objects { g.upsertObject(o) }
        for r in self.relations { g.addRelation(r) }
        for p in self.predicates { g.addPredicate(p) }
        return g
    }

    func stateKey() -> String {
        let keys = self.predicates.map { $0.name + ($0.arguments.first ?? "") }.sorted()
        return keys.joined(separator: "|")
    }

    func ensureStage() -> WorldStateGraph {
        if self.predicates.contains(Predicate("stage_observe")) ||
            self.predicates.contains(Predicate("stage_analyze")) ||
            self.predicates.contains(Predicate("stage_decide")) ||
            self.predicates.contains(Predicate("stage_act")) {
            return self
        }
        let g = self.copy()
        g.addPredicate(Predicate("stage_observe"))
        return g
    }
}
