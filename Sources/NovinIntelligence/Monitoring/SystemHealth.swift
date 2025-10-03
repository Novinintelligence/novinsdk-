import Foundation

/// System health monitoring for enterprise deployments
@available(iOS 15.0, macOS 12.0, *)
public struct SystemHealth: Codable {
    public let status: HealthStatus
    public let assessmentQueueSize: Int
    public let telemetryStorageBytes: Int
    public let userPatternsStorageBytes: Int
    public let lastAssessmentTime: Date?
    public let uptime: TimeInterval
    public let totalAssessments: Int
    public let errorCount: Int
    public let averageProcessingTimeMs: Double
    public let rateLimit: RateLimitHealth
    
    public enum HealthStatus: String, Codable {
        case healthy
        case degraded
        case critical
        case emergency
    }
    
    public struct RateLimitHealth: Codable {
        public let currentTokens: Double
        public let maxTokens: Double
        public let utilizationPercent: Double
    }
    
    /// Get overall health description
    public var description: String {
        """
        System Health: \(status.rawValue.uppercased())
        - Assessments: \(totalAssessments) total, \(errorCount) errors
        - Performance: \(String(format: "%.1f", averageProcessingTimeMs))ms avg
        - Rate Limit: \(String(format: "%.0f", rateLimit.utilizationPercent))% utilized
        - Storage: Telemetry \(telemetryStorageBytes) bytes, Patterns \(userPatternsStorageBytes) bytes
        - Uptime: \(String(format: "%.0f", uptime))s
        """
    }
}

/// Health monitor singleton
@available(iOS 15.0, macOS 12.0, *)
public final class HealthMonitor: @unchecked Sendable {
    public static let shared = HealthMonitor()
    
    private let queue = DispatchQueue(label: "com.novinintelligence.healthmonitor")
    private var startTime: Date = Date()
    private var totalAssessments: Int = 0
    private var errorCount: Int = 0
    private var processingTimes: [Double] = []
    private var lastAssessmentTime: Date?
    private let maxProcessingTimesStored = 100
    
    private init() {}
    
    /// Record successful assessment
    public func recordAssessment(processingTimeMs: Double) {
        queue.async {
            self.totalAssessments += 1
            self.lastAssessmentTime = Date()
            self.processingTimes.append(processingTimeMs)
            if self.processingTimes.count > self.maxProcessingTimesStored {
                self.processingTimes.removeFirst()
            }
        }
    }
    
    /// Record error
    public func recordError() {
        queue.async {
            self.errorCount += 1
        }
    }
    
    /// Get current system health
    public func getHealth(rateLimiter: RateLimiter, queueSize: Int = 0) -> SystemHealth {
        return queue.sync {
            let avgProcessingTime = processingTimes.isEmpty ? 0.0 : processingTimes.reduce(0, +) / Double(processingTimes.count)
            
            // Calculate storage sizes
            let telemetrySize = estimateTelemetrySize()
            let patternsSize = estimateUserPatternsSize()
            
            // Determine health status
            let status = calculateHealthStatus(
                queueSize: queueSize,
                errorRate: Double(errorCount) / max(1, Double(totalAssessments)),
                avgProcessingTime: avgProcessingTime
            )
            
            // Rate limit health
            let currentTokens = rateLimiter.getCurrentTokens()
            let rateLimitHealth = SystemHealth.RateLimitHealth(
                currentTokens: currentTokens,
                maxTokens: 100,  // From RateLimiter default
                utilizationPercent: ((100 - currentTokens) / 100) * 100
            )
            
            return SystemHealth(
                status: status,
                assessmentQueueSize: queueSize,
                telemetryStorageBytes: telemetrySize,
                userPatternsStorageBytes: patternsSize,
                lastAssessmentTime: lastAssessmentTime,
                uptime: Date().timeIntervalSince(startTime),
                totalAssessments: totalAssessments,
                errorCount: errorCount,
                averageProcessingTimeMs: avgProcessingTime,
                rateLimit: rateLimitHealth
            )
        }
    }
    
    /// Reset health monitor (for testing)
    public func reset() {
        queue.sync {
            startTime = Date()
            totalAssessments = 0
            errorCount = 0
            processingTimes = []
            lastAssessmentTime = nil
        }
    }
    
    // MARK: - Private Helpers
    
    private func calculateHealthStatus(queueSize: Int, errorRate: Double, avgProcessingTime: Double) -> SystemHealth.HealthStatus {
        // Emergency: Critical failures
        if errorRate > 0.5 {
            return .emergency
        }
        
        // Critical: High error rate or severe performance degradation
        if errorRate > 0.2 || avgProcessingTime > 500 {
            return .critical
        }
        
        // Degraded: Moderate issues
        if errorRate > 0.05 || avgProcessingTime > 100 || queueSize > 50 {
            return .degraded
        }
        
        // Healthy: All good
        return .healthy
    }
    
    private func estimateTelemetrySize() -> Int {
        // Estimate based on telemetry metrics
        let metrics = TemporalTelemetry.shared.getMetrics()
        // Rough estimate: 200 bytes per event
        return metrics.totalEvents * 200
    }
    
    private func estimateUserPatternsSize() -> Int {
        // Estimate based on user patterns - use dummy size since we can't access private static
        // This is just for health monitoring estimation anyway
        return 2000  // Rough estimate: ~2KB for patterns
    }
}
