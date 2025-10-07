import Foundation

/// Online normality tracker (training-free). Maintains running mean for numeric features.
public final class NormalityTracker {
    private var count: Int = 0
    private var means: [String: Double] = [:]

    public init() {}

    /// Update running statistics with a new observation
    public func update(features: [String: Double]) {
        count += 1
        for (k, v) in features {
            let old = means[k] ?? 0.0
            let newMean = old + (v - old) / Double(count)
            means[k] = newMean
        }
    }

    /// Compute a simple normality score in [0,1] inversely proportional to L1 distance from mean
    public func score(features: [String: Double], scale: Double = 10.0) -> Double {
        guard count > 0 else { return 0.5 }
        var dist: Double = 0.0
        for (k, v) in features {
            let m = means[k] ?? v
            dist += abs(v - m)
        }
        let s = 1.0 / (1.0 + dist / max(1.0, scale))
        return min(1.0, max(0.0, s))
    }
}
