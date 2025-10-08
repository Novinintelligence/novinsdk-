import Foundation

/// Training-free threat scoring using hardcoded primitives
public final class FearHeuristic {
    public struct Config: Codable {
        public var weights: [String: Double] // primitive -> weight
        public var thresholds: [String: Double] // primitive -> threshold
        public init(weights: [String: Double] = [:], thresholds: [String: Double] = [:]) {
            self.weights = weights
            self.thresholds = thresholds
        }
    }

    private let config: Config

    public init(config: Config = .init(
        weights: [
            "sudden_motion": 0.4,
            "sharp_edges_approaching": 0.4,
            "loud_sound": 0.2
        ],
        thresholds: [
            "sudden_motion": 0.7,
            "sharp_edges_approaching": 0.7,
            "loud_sound": 0.8
        ]
    )) {
        self.config = config
    }

    /// Compute fear/threat score in [0,1] from feature map.
    /// Derives primitives from lightweight named features produced by FeatureExtractorSwift.
    public func score(features: [String: Double]) -> Double {
        // Derive primitives from available features (all in [0,1])
        let motion = features["event_motion"] ?? 0.0
        let duration = features["event_duration"] ?? 0.0 // 0..1 scaled by 600s
        let sound = features["event_sound"] ?? 0.0
        let intensity = features["event_intensity"] ?? 0.0
        let glass = features["event_glassbreak"] ?? 0.0

        // Sudden motion: strong motion with very short duration
        let sudden_motion = max(0.0, min(1.0, motion * max(0.0, 0.25 - duration) / 0.25))
        // Sharp edges approaching proxy: glassbreak or door+impact (fallback to glass)
        let sharp_edges_approaching = glass
        // Loud sound: sound event with high intensity
        let loud_sound = max(0.0, min(1.0, sound * intensity))

        let primitives: [String: Double] = [
            "sudden_motion": sudden_motion,
            "sharp_edges_approaching": sharp_edges_approaching,
            "loud_sound": loud_sound
        ]

        var total: Double = 0.0
        for (name, value) in primitives {
            let w = config.weights[name] ?? 0.0
            let t = config.thresholds[name] ?? 1.0
            if value >= t {
                // scale contribution above threshold into [0,1]
                let scaled = (t < 1.0) ? min(1.0, (value - t) / (1.0 - t)) : 1.0
                total += w * scaled
            }
        }
        return min(1.0, max(0.0, total))
    }
}
