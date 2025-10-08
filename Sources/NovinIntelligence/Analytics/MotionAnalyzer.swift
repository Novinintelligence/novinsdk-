import Foundation
import Accelerate

/// Real motion vector analysis using Accelerate framework
@available(iOS 15.0, macOS 12.0, *)
public struct MotionAnalyzer {
    
    // MARK: - Types
    
    public struct MotionFeatures {
        public let duration: TimeInterval
        public let energy: Double          // Total motion energy (0-1)
        public let peakIntensity: Double   // Maximum intensity spike (0-1)
        public let vectorNorm: Double      // L2 norm of motion vector
        public let activityType: ActivityType
        public let confidence: Double
        
        public enum ActivityType: String {
            case stationary      // No significant motion
            case walking         // Human walking pattern
            case running         // Fast movement
            case vehicle         // Car/bike motion pattern
            case pet             // Small animal pattern
            case package_drop    // Brief, low energy
            case loitering       // Slow, sustained
            case unknown
        }
    }
    
    // MARK: - Analysis
    
    /// Analyze raw motion data to extract features
    /// - Parameters:
    ///   - rawData: Array of motion intensities over time (0-1 range)
    ///   - sampleRate: Samples per second
    ///   - duration: Total duration in seconds
    /// - Returns: Extracted motion features
    public static func analyzeMotionVector(_ rawData: [Double], sampleRate: Double = 10.0, duration: TimeInterval) -> MotionFeatures {
        guard !rawData.isEmpty else {
            return MotionFeatures(
                duration: 0,
                energy: 0,
                peakIntensity: 0,
                vectorNorm: 0,
                activityType: .stationary,
                confidence: 1.0
            )
        }
        
        // 1. Calculate energy (integral of motion over time)
        let energy = calculateEnergy(rawData)
        
        // 2. Find peak intensity
        let peakIntensity = rawData.max() ?? 0.0
        
        // 3. Calculate L2 norm (magnitude of motion vector)
        let vectorNorm = calculateVectorNorm(rawData)
        
        // 4. Classify activity type
        let (activityType, confidence) = classifyActivity(
            rawData: rawData,
            duration: duration,
            energy: energy,
            peakIntensity: peakIntensity,
            vectorNorm: vectorNorm
        )
        
        return MotionFeatures(
            duration: duration,
            energy: energy,
            peakIntensity: peakIntensity,
            vectorNorm: vectorNorm,
            activityType: activityType,
            confidence: confidence
        )
    }
    
    /// Analyze motion from metadata (backwards compatibility)
    public static func analyzeFromMetadata(_ metadata: [String: Any]) -> MotionFeatures {
        let duration = metadata["duration"] as? Double ?? 0.0
        let energy = metadata["energy"] as? Double ?? 0.0
        
        // If no raw data, estimate from metadata
        let activityType: MotionFeatures.ActivityType
        if duration < 5 && energy < 0.3 {
            activityType = .package_drop
        } else if duration > 30 && energy < 0.5 {
            activityType = .loitering
        } else if energy > 0.7 {
            activityType = .running
        } else {
            activityType = .walking
        }
        
        return MotionFeatures(
            duration: duration,
            energy: energy,
            peakIntensity: energy,
            vectorNorm: energy,
            activityType: activityType,
            confidence: 0.6  // Lower confidence without raw data
        )
    }
    
    // MARK: - Private Helpers
    
    /// Calculate total energy using Accelerate
    private static func calculateEnergy(_ data: [Double]) -> Double {
        var mutableData = data
        var sum: Double = 0.0
        
        // Use vDSP for efficient sum of squares
        vDSP_svesqD(&mutableData, 1, &sum, vDSP_Length(data.count))
        
        // Normalize by count
        let energy = sqrt(sum / Double(data.count))
        
        return min(1.0, energy)
    }
    
    /// Calculate L2 norm using Accelerate
    private static func calculateVectorNorm(_ data: [Double]) -> Double {
        var mutableData = data
        var norm: Double = 0.0
        
        // Use vDSP for efficient L2 norm
        vDSP_svesqD(&mutableData, 1, &norm, vDSP_Length(data.count))
        
        return sqrt(norm)
    }
    
    /// Classify activity type based on motion characteristics
    private static func classifyActivity(
        rawData: [Double],
        duration: TimeInterval,
        energy: Double,
        peakIntensity: Double,
        vectorNorm: Double
    ) -> (MotionFeatures.ActivityType, Double) {
        
        // Calculate additional features
        let variance = calculateVariance(rawData)
        let _ = rawData.reduce(0, +) / Double(rawData.count)  // avgIntensity (reserved for future use)
        
        // Classification rules
        
        // Stationary: Low energy, short duration
        if energy < 0.1 && duration < 2 {
            return (.stationary, 0.95)
        }
        
        // Package drop: Brief (<10s), low-medium energy, low variance
        if duration < 10 && energy < 0.4 && variance < 0.1 {
            return (.package_drop, 0.88)
        }
        
        // Pet: Short duration, low-medium energy, high variance (erratic)
        if duration < 15 && energy < 0.5 && variance > 0.15 {
            return (.pet, 0.82)
        }
        
        // Loitering: Long duration (>30s), medium energy, low variance
        if duration > 30 && energy > 0.3 && energy < 0.6 && variance < 0.12 {
            return (.loitering, 0.85)
        }
        
        // Running: High energy, high peak
        if energy > 0.7 || peakIntensity > 0.8 {
            return (.running, 0.90)
        }
        
        // Vehicle: Very high energy, sustained
        if energy > 0.85 && duration > 5 {
            return (.vehicle, 0.75)
        }
        
        // Walking: Medium energy, medium duration
        if energy > 0.3 && energy < 0.7 && duration > 5 {
            return (.walking, 0.80)
        }
        
        // Unknown
        return (.unknown, 0.50)
    }
    
    /// Calculate variance
    private static func calculateVariance(_ data: [Double]) -> Double {
        let mean = data.reduce(0, +) / Double(data.count)
        let variance = data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(data.count)
        return variance
    }
}

// MARK: - Lightweight fuzzy micro-kernel (dependency-free)

@inlinable
func trapmf(_ x: Double, _ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
    if x <= a || x >= d { return 0 }
    if x >= b && x <= c { return 1 }
    if x > a && x < b { return (x - a) / max(1e-9, (b - a)) }
    return (d - x) / max(1e-9, (d - c))
}

struct MotionFuzzyKernel {
    struct Members {
        let durS, durM, durL: Double
        let eL, eM, eH: Double
        let entry, perim, interior: Double
        let day, night: Double
        let home, away, vac: Double
        let pet: Double
    }

    @inlinable
    static func memberships(duration: Double,
                            energy: Double,
                            zoneRisk: Double,
                            hour: Int,
                            mode: String,
                            activityHint: String?) -> Members {
        // Duration (sec)
        let durS = trapmf(duration, 0, 0, 6, 10)
        let durM = trapmf(duration, 6, 10, 20, 30)
        let durL = trapmf(duration, 20, 30, 120, 999)

        // Energy (0..1)
        let eL = trapmf(energy, 0.0, 0.0, 0.1, 0.15)
        let eM = trapmf(energy, 0.1, 0.18, 0.3, 0.4)
        let eH = trapmf(energy, 0.3, 0.5, 1.0, 1.0)

        // Zone (soft memberships from risk)
        let entry = trapmf(zoneRisk, 0.6, 0.65, 0.8, 1.0)
        let perim = trapmf(zoneRisk, 0.5, 0.6, 0.7, 0.8)
        let interior = trapmf(zoneRisk, 0.2, 0.25, 0.45, 0.55)

        // Time-of-day (simple day/night split; soft shoulders can be added later)
        let night = (hour < 6 || hour >= 22) ? 1.0 : 0.0
        let day = 1.0 - night

        // Mode
        let home = mode == "home" ? 1.0 : 0.0
        let away = mode == "away" ? 1.0 : 0.0
        let vac  = mode == "vacation" ? 1.0 : 0.0

        // Activity hint
        let pet = (activityHint == "pet") ? 1.0 : 0.0

        return Members(durS: durS, durM: durM, durL: durL,
                       eL: eL, eM: eM, eH: eH,
                       entry: entry, perim: perim, interior: interior,
                       day: day, night: night,
                       home: home, away: away, vac: vac,
                       pet: pet)
    }

    @inlinable
    static func infer(_ m: Members) -> (intent: String, intentScores: [String: Double], threat: Double, rules: [String]) {
        var scores: [String: Double] = [:]
        var fired: [String] = []

        // Delivery (short, low energy, entry, day)
        let r_delivery = min(m.durS, min(m.eL, min(m.entry, m.day)))
        if r_delivery > 0 {
            scores["delivery", default: 0] += 0.85 * r_delivery
            fired.append("delivery_short_low_entry_day")
        }

        // Loitering (long, medium energy, away/vac)
        let r_loitering = min(m.durL, min(m.eM, max(m.away, m.vac)))
        if r_loitering > 0 {
            scores["loitering", default: 0] += 0.8 * r_loitering
            fired.append("loitering_long_medium_away_vac")
        }

        // Prowler (long, med-high energy, perimeter or night)
        let r_prowler = min(m.durL, max(m.eM, m.eH)) * max(m.perim, m.night)
        if r_prowler > 0 {
            scores["prowler", default: 0] += 0.85 * r_prowler
            fired.append("prowler_long_energy_perimeter_or_night")
        }

        // Pet (home, low energy, interior/perimeter)
        let r_pet = min(m.home, m.eL) * max(m.interior, m.perim) * max(0.6, m.pet)
        if r_pet > 0 {
            scores["pet", default: 0] += 0.9 * r_pet
            fired.append("pet_low_energy_home")
        }

        let total = max(1e-9, scores.values.reduce(0, +))
        let norm = scores.mapValues { $0 / total }
        // Threat mapping: delivery~0.2, pet~0.1, loitering~0.5, prowler~0.75
        let threat = (norm["delivery"] ?? 0)*0.2 +
                     (norm["pet"] ?? 0)*0.1 +
                     (norm["loitering"] ?? 0)*0.5 +
                     (norm["prowler"] ?? 0)*0.75
        let intent = norm.max(by: { $0.value < $1.value })?.key ?? "unknown"
        return (intent, norm, threat, fired)
    }
}

extension MotionAnalyzer {
    /// Fuzzy assessment helper for metadata-driven motion analysis
    /// - Returns: intent label, crisp threat in 0..1, and fired fuzzy rules
    static func fuzzyAssess(duration: Double,
                            energy: Double,
                            zoneRisk: Double,
                            eventHour: Int,
                            homeMode: String,
                            activityHint: String?) -> (intent: String, intentScores: [String: Double], threat: Double, rules: [String]) {
        let m = MotionFuzzyKernel.memberships(duration: duration,
                                              energy: energy,
                                              zoneRisk: zoneRisk,
                                              hour: eventHour,
                                              mode: homeMode,
                                              activityHint: activityHint)
        return MotionFuzzyKernel.infer(m)
    }
}
