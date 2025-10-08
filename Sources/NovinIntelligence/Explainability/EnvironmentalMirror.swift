import Foundation

/// Compares predicted vs observed symbolic states and reports mismatches
public final class EnvironmentalMirror {
    public init() {}

    public struct Diff: Codable {
        public let missingPredicates: [Predicate]
        public let unexpectedPredicates: [Predicate]
    }

    public func diff(predicted: Set<Predicate>, observed: Set<Predicate>) -> Diff {
        let missing = predicted.subtracting(observed)
        let unexpected = observed.subtracting(predicted)
        return Diff(missingPredicates: Array(missing), unexpectedPredicates: Array(unexpected))
    }
}
