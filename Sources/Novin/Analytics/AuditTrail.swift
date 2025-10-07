import Foundation
import CryptoKit

/// Enterprise audit trail for explainability and compliance
@available(iOS 15.0, macOS 12.0, *)
public struct AuditTrail: Codable {
    public let requestId: UUID
    public let timestamp: Date
    public let inputHash: String                // Privacy-safe hash of input
    public let configVersion: String            // SDK/config version
    public let sdkMode: String                  // Operating mode
    
    // Decision breakdown
    public let eventType: String?
    public let eventLocation: String?
    public let intermediateScores: [String: Double]
    public let rulesTriggered: [String]
    public let chainPattern: String?
    public let motionAnalysis: String?
    public let zoneRiskScore: Double?
    
    // Final decision
    public let finalThreatLevel: String
    public let finalScore: Double
    public let confidence: Double
    public let processingTimeMs: Double
    
    // Reasoning
    public let fusionBreakdown: FusionBreakdown
    public let temporalFactors: [String: String]
    
    public struct FusionBreakdown: Codable {
        public let bayesianScore: Double
        public let ruleBasedScore: Double
        public let mentalModelAdjustment: Double
        public let temporalDampening: Double
        public let chainPatternAdjustment: Double
        public let finalScore: Double
    }
    
    /// Export as JSON
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    /// Create privacy-safe hash of input
    public static func hashInput(_ input: [String: Any]) -> String {
        // Create deterministic string representation
        let jsonData = try? JSONSerialization.data(withJSONObject: input, options: [.sortedKeys])
        guard let data = jsonData else { return "invalid_input" }
        
        // SHA256 hash
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Audit trail manager
@available(iOS 15.0, macOS 12.0, *)
public final class AuditTrailManager: @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "com.novinintelligence.audittrail")
    private var trails: [AuditTrail] = []
    private let maxTrailsStored: Int = 1000
    private let persistenceKey = "com.novinintelligence.audittrails"
    
    public static let shared = AuditTrailManager()
    
    private init() {
        loadFromDisk()
    }
    
    /// Record audit trail
    public func record(_ trail: AuditTrail) {
        queue.async {
            self.trails.append(trail)
            
            // Enforce max size
            if self.trails.count > self.maxTrailsStored {
                self.trails.removeFirst(self.trails.count - self.maxTrailsStored)
            }
            
            // Persist to disk
            self.saveToDisk()
        }
    }
    
    /// Get recent trails
    public func getRecentTrails(limit: Int = 100) -> [AuditTrail] {
        return queue.sync {
            Array(trails.suffix(limit))
        }
    }
    
    /// Get trail by request ID
    public func getTrail(requestId: UUID) -> AuditTrail? {
        return queue.sync {
            trails.first { $0.requestId == requestId }
        }
    }
    
    /// Export all trails as JSON
    public func exportAllTrails() -> String? {
        return queue.sync {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted]
            guard let data = try? encoder.encode(trails),
                  let json = String(data: data, encoding: .utf8) else {
                return nil
            }
            return json
        }
    }
    
    /// Clear all trails
    public func reset() {
        queue.sync {
            trails.removeAll()
            saveToDisk()
        }
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(trails) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
    
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        trails = (try? decoder.decode([AuditTrail].self, from: data)) ?? []
    }
}




