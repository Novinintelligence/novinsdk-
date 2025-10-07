import Foundation

// P1: Minimal belief store (deterministic, lightweight)
// - Tracks simple hypothesis beliefs per key (e.g., zone or sensor)
// - Update rule: multiplicative evidence followed by normalization
// - No decay here (added in P2). No randomness.
struct MinimalBeliefStore {
    private var store: [String: [String: Double]] = [:]
    private let eps: Double = 1e-9

    mutating func update(key: String, evidence: [String: Double]) -> (prev: [String: Double], next: [String: Double]) {
        var prev = store[key] ?? defaultBeliefs()
        var next = prev
        // Multiply in evidence likelihoods (clamped), then normalize
        for (hyp, like) in evidence {
            let likelihood = min(1.0, max(eps, like))
            let prior = prev[hyp] ?? 0.25
            next[hyp] = max(eps, prior * likelihood)
        }
        // Ensure all hypotheses exist
        for hyp in defaultBeliefKeys() where next[hyp] == nil { next[hyp] = eps }
        // Normalize to sum = 1
        let sumVal = max(eps, next.values.reduce(0, +))
        for (k, v) in next { next[k] = v / sumVal }
        store[key] = next
        return (prev, next)
    }

    private func defaultBeliefs() -> [String: Double] {
        var b: [String: Double] = [:]
        for k in defaultBeliefKeys() { b[k] = 0.25 }
        return b
    }

    private func defaultBeliefKeys() -> [String] {
        return ["delivery", "intrusion", "prowler", "pet"]
    }
}
