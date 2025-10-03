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
