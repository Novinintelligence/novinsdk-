import Foundation
import os.log

/// Main NovinIntelligence SDK class - Enterprise Edition
@available(iOS 15.0, macOS 12.0, *)
public final class NovinIntelligence: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = NovinIntelligence()
    
    // MARK: - State
    private var isInitialized = false
    private var currentMode: SDKMode = .full
    
    // MARK: - Processing
    private let processingQueue = DispatchQueue(label: "com.novinintelligence.processing", qos: .userInitiated)
    
    // MARK: - Core AI Components
    private let featureExtractor = FeatureExtractorSwift()
    private var reasoningEngine = ReasoningSwift()
    private let fusionEngine = IntelligentFusion()
    
    // MARK: - Enterprise Components
    private let rateLimiter = RateLimiter(maxTokens: 100, refillRate: 100)
    private let eventChainAnalyzer = EventChainAnalyzer()
    private let zoneClassifier = ZoneClassifier()
    
    // MARK: - Version
    public static let sdkVersion = "2.0.0-enterprise"
    
    private init() {}
    
    // MARK: - Enterprise Configuration API
    
    // Private static storage for enterprise config (accessed via instance methods)
    private static var sharedTemporalConfig: TemporalConfiguration = .default
    private static var sharedUserPatterns: UserPatterns = UserPatterns.load()
    
    /// Configure temporal intelligence settings
    /// - Parameter config: Temporal configuration (default, aggressive, or conservative)
    public func configure(temporal config: TemporalConfiguration) throws {
        try config.validate()
        Self.sharedTemporalConfig = config
    }
    
    /// Get current temporal configuration
    public func getTemporalConfiguration() -> TemporalConfiguration {
        return Self.sharedTemporalConfig
    }
    
    /// Get user patterns
    internal func getUserPatterns() -> UserPatterns {
        return Self.sharedUserPatterns
    }
    
    /// Set user patterns
    internal func setUserPatterns(_ patterns: UserPatterns) {
        Self.sharedUserPatterns = patterns
    }
    
    /// Provide user feedback for pattern learning (validated)
    /// - Parameters:
    ///   - eventType: Type of event (e.g., "doorbell_motion")
    ///   - wasFalsePositive: Whether user marked as false positive
    public func provideFeedback(eventType: String, wasFalsePositive: Bool) {
        // Only allow in full or degraded mode
        guard currentMode.isFeatureAvailable(.userPatternLearning) else { return }
        
        // Validate event type is reasonable
        guard eventType.count <= 100, !eventType.isEmpty else { return }
        
        var patterns = Self.sharedUserPatterns
        patterns.learn(eventType: eventType, wasFalsePositive: wasFalsePositive)
        try? patterns.save()
        Self.sharedUserPatterns = patterns
    }
    
    /// Get user pattern insights
    public func getUserPatternInsights() -> DeliveryPatternInsights {
        return Self.sharedUserPatterns.getDeliveryPatternInsights()
    }
    
    /// Get telemetry metrics (privacy-safe)
    public func getTelemetryMetrics() -> DampeningMetrics {
        return TemporalTelemetry.shared.getMetrics()
    }
    
    /// Export telemetry as JSON
    public func exportTelemetry() -> String? {
        return TemporalTelemetry.shared.exportMetrics()
    }
    
    /// Reset user patterns (for testing or user request)
    public func resetUserPatterns() {
        var patterns = Self.sharedUserPatterns
        patterns.reset()
        try? patterns.save()
        Self.sharedUserPatterns = patterns
    }
    
    // MARK: - Enterprise Health & Monitoring
    
    /// Get current system health
    public func getSystemHealth() -> SystemHealth {
        return HealthMonitor.shared.getHealth(rateLimiter: rateLimiter)
    }
    
    /// Get current SDK operational mode
    public func getCurrentMode() -> SDKMode {
        return currentMode
    }
    
    /// Set SDK operational mode (for testing or degraded operation)
    public func setMode(_ mode: SDKMode) {
        currentMode = mode
        Logger(subsystem: "com.novinintelligence", category: "mode").info("SDK mode changed to: \(mode.rawValue)")
    }
    
    /// Get audit trail for request
    public func getAuditTrail(requestId: UUID) -> AuditTrail? {
        return AuditTrailManager.shared.getTrail(requestId: requestId)
    }
    
    /// Get recent audit trails
    public func getRecentAuditTrails(limit: Int = 100) -> [AuditTrail] {
        return AuditTrailManager.shared.getRecentTrails(limit: limit)
    }
    
    /// Export all audit trails as JSON
    public func exportAuditTrails() -> String? {
        return AuditTrailManager.shared.exportAllTrails()
    }
    
    /// Reset rate limiter (for testing)
    public func resetRateLimiter() {
        rateLimiter.reset()
    }
    
    // MARK: - Initialization
    
    /// Initialize the NovinIntelligence SDK with enterprise features
    /// - Parameter brandConfig: Optional brand-specific configuration
    public func initialize(brandConfig: String? = nil) async throws {
        guard !isInitialized else { return }
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    // Load rules from bundled JSON (or fallback)
                    var engine = self.reasoningEngine
                    let count = engine.loadRules()
                    self.reasoningEngine = engine

                    // Perform a lightweight feature extraction sanity check
                    let sanity = self.featureExtractor.extractNamedFeatures(from: [:])
                    if sanity.isEmpty {
                        // Graceful degradation: Fall back to minimal mode
                        self.currentMode = .minimal
                        Logger(subsystem: "com.novinintelligence", category: "init").warning("Feature extraction failed, entering minimal mode")
                    }
                    
                    // Load user patterns (graceful degradation if fails)
                    // Note: UserPatterns.load() doesn't throw, but we wrap for future-proofing
                    Self.sharedUserPatterns = UserPatterns.load()
                    
                    self.isInitialized = true
                    Logger(subsystem: "com.novinintelligence", category: "init").info("✅ SDK v\(Self.sdkVersion) initialized with \(count) rules, mode: \(self.currentMode.rawValue)")
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Main API
    
    /// Process security event and return threat assessment with enterprise AI
    public func assess(requestJson: String) async throws -> SecurityAssessment {
        guard isInitialized else { throw NovinIntelligenceError.notInitialized }
        
        // P0.2: Rate limiting
        guard rateLimiter.allow() else {
            HealthMonitor.shared.recordError()
            throw InputValidator.ValidationError.rateLimitExceeded
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                let start = Date()
                let requestId = UUID()
                
                do {
                    // P0.1: Input validation
                    let request = try InputValidator.validateInput(requestJson)
                    
                    // Emergency mode: Return safe default
                    if self.currentMode == .emergency {
                        let assessment = SecurityAssessment(
                            threatLevel: .standard,
                            confidence: 0.5,
                            processingTimeMs: Date().timeIntervalSince(start) * 1000.0,
                            reasoning: "Emergency mode: Safe fallback response",
                            requestId: requestId.uuidString,
                            timestamp: ISO8601DateFormatter().string(from: Date())
                        )
                        continuation.resume(returning: assessment)
                        return
                    }
                    
                    // P1.1: Event chain analysis
                    var chainPattern: EventChainAnalyzer.ChainPattern?
                    var chainAdjustment: Double = 0.0
                    if let eventType = request["type"] as? String,
                       let timestamp = request["timestamp"] as? Double,
                       let metadata = request["metadata"] as? [String: Any],
                       let locationStr = metadata["location"] as? String {
                        let event = EventChainAnalyzer.SecurityEvent(
                            type: eventType,
                            timestamp: Date(timeIntervalSince1970: timestamp),
                            location: locationStr,
                            confidence: request["confidence"] as? Double ?? 0.5,
                            metadata: request
                        )
                        chainPattern = self.eventChainAnalyzer.analyzeChain(event)
                        chainAdjustment = chainPattern?.threatDelta ?? 0.0
                    }
                    
                    // P1.3: Zone classification
                    var zoneRiskScore: Double = 0.5
                    if let metadata = request["metadata"] as? [String: Any],
                       let location = metadata["location"] as? String {
                        zoneRiskScore = self.zoneClassifier.getRiskScore(for: location)
                    }
                    
                    // 1) Extract named features
                    var features = self.featureExtractor.extractNamedFeatures(from: request)
                    
                    // P1.2: Motion analysis (if motion event)
                    var motionAnalysis: String?
                    var motionFeatures: MotionAnalyzer.MotionFeatures?
                    if let metadata = request["metadata"] as? [String: Any],
                       (request["type"] as? String)?.contains("motion") == true {
                        let analyzed = MotionAnalyzer.analyzeFromMetadata(metadata)
                        motionFeatures = analyzed
                        motionAnalysis = "\(analyzed.activityType.rawValue) (\(String(format: "%.0f", analyzed.confidence * 100))%)"
                        
                        // Adjust features based on motion analysis
                        if analyzed.activityType == .package_drop {
                            features["event_motion"] = (features["event_motion"] ?? 1.0) * 0.6
                        } else if analyzed.activityType == .loitering {
                            features["event_motion"] = (features["event_motion"] ?? 1.0) * 1.3
                        }
                    }
                    
                    // Inject zone risk into features
                    features["zone_risk"] = zoneRiskScore
                    
                    // 2) Rule reasoning (skip in minimal mode)
                    var ruleResult: ReasoningSwift.Result
                    if self.currentMode == .minimal {
                        ruleResult = ReasoningSwift.Result(
                            assessment: "minimal_mode",
                            confidence: 0.5,
                            chain: [],
                            factors: [],
                            recommendations: [],
                            riskScore: 0.5
                        )
                    } else {
                        ruleResult = self.reasoningEngine.reason(request: request, features: features)
                    }
                    
                    // 3) Mathematical fusion (skip in minimal mode)
                    var fused: IntelligentFusion.FusionResult
                    if self.currentMode == .minimal {
                        fused = IntelligentFusion.FusionResult(
                            finalScore: ruleResult.riskScore,
                            confidence: ruleResult.confidence,
                            explanation: [],
                            bayesianContribution: 0.0,
                            ruleContribution: 1.0
                        )
                    } else {
                        fused = self.fusionEngine.fuse(features: features, rules: ruleResult, request: request)
                    }
                    
                    // 4) Apply chain pattern adjustment
                    var finalScore = fused.finalScore + chainAdjustment
                    finalScore = max(0.0, min(1.0, finalScore))
                    
                    // 5) Map and build assessment
                    let level = self.mapScoreToThreatLevel(finalScore)
                    let reasoning = self.buildExplanation(
                        fused: fused,
                        rules: ruleResult,
                        chainPattern: chainPattern,
                        motionAnalysis: motionAnalysis,
                        zoneRiskScore: zoneRiskScore
                    )
                    
                    // 6) Generate personalized, adaptive explanation
                    let zone = self.zoneClassifier.classifyLocation(
                        (request["metadata"] as? [String: Any])?["location"] as? String ?? "unknown"
                    )
                    let config = self.getTemporalConfiguration()
                    let calendar = Calendar.current
                    var calendarWithTZ = calendar
                    calendarWithTZ.timeZone = config.timezone
                    let now = Date()
                    let currentHour = calendarWithTZ.component(.hour, from: now)
                    let isDeliveryWindow = (config.deliveryWindowStart...config.deliveryWindowEnd).contains(currentHour)
                    let isNight = currentHour >= config.nightStart || currentHour < config.nightEnd
                    
                    let timeContext = ExplanationEngine.TimeContext(
                        currentHour: currentHour,
                        isNight: isNight,
                        isDeliveryWindow: isDeliveryWindow,
                        deliveryWindowStart: config.deliveryWindowStart,
                        deliveryWindowEnd: config.deliveryWindowEnd
                    )
                    
                    let explanation = ExplanationEngine.explain(
                        threatLevel: level,
                        chainPattern: chainPattern,
                        motionAnalysis: motionFeatures,
                        zone: zone,
                        timeContext: timeContext,
                        userPatterns: Self.sharedUserPatterns,
                        eventType: request["type"] as? String ?? "unknown",
                        homeMode: (request["metadata"] as? [String: Any])?["home_mode"] as? String ?? "home"
                    )
                    
                    let ms = Date().timeIntervalSince(start) * 1000.0
                    let assessment = SecurityAssessment(
                        threatLevel: level,
                        confidence: fused.confidence,
                        processingTimeMs: ms,
                        reasoning: reasoning,
                        requestId: requestId.uuidString,
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        summary: explanation.summary,
                        detailedReasoning: explanation.reasoning,
                        context: explanation.context,
                        recommendation: explanation.recommendation
                    )
                    
                    // P0.3: Health monitoring
                    HealthMonitor.shared.recordAssessment(processingTimeMs: ms)
                    
                    // P1.4: Audit trail
                    let auditTrail = AuditTrail(
                        requestId: requestId,
                        timestamp: Date(),
                        inputHash: AuditTrail.hashInput(request),
                        configVersion: Self.sdkVersion,
                        sdkMode: self.currentMode.rawValue,
                        eventType: request["type"] as? String,
                        eventLocation: (request["metadata"] as? [String: Any])?["location"] as? String,
                        intermediateScores: [
                            "bayesian": fused.bayesianContribution,
                            "rules": fused.ruleContribution,
                            "chain_adjustment": chainAdjustment,
                            "zone_risk": zoneRiskScore
                        ],
                        rulesTriggered: ruleResult.factors,
                        chainPattern: chainPattern?.name,
                        motionAnalysis: motionAnalysis,
                        zoneRiskScore: zoneRiskScore,
                        finalThreatLevel: level.rawValue,
                        finalScore: finalScore,
                        confidence: fused.confidence,
                        processingTimeMs: ms,
                        fusionBreakdown: AuditTrail.FusionBreakdown(
                            bayesianScore: fused.bayesianContribution,
                            ruleBasedScore: fused.ruleContribution,
                            mentalModelAdjustment: 0.0,
                            temporalDampening: 0.0,
                            chainPatternAdjustment: chainAdjustment,
                            finalScore: finalScore
                        ),
                        temporalFactors: [:]
                    )
                    AuditTrailManager.shared.record(auditTrail)
                    
                    continuation.resume(returning: assessment)
                } catch {
                    // P0.3: Record error in health monitor
                    HealthMonitor.shared.recordError()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Assess and return PI-format JSON string for partner ingestion
    public func assessPI(requestJson: String) async throws -> String {
        let result = try await assess(requestJson: requestJson)
        return try result.toPI()
    }
    
    /// Feed any security event to the AI engine
    public func feedSecurityEvent(_ event: Any) async {
        guard isInitialized else {
            print("⚠️ NovinIntelligence not initialized")
            return
        }
        
        if let jsonString = event as? String {
            _ = try? await assess(requestJson: jsonString)
        } else if let dictionary = event as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dictionary),
                  let jsonString = String(data: jsonData, encoding: .utf8) {
            _ = try? await assess(requestJson: jsonString)
        }
    }
    
    /// Set system mode for threat assessment context
    public func setSystemMode(_ mode: String) {
        print("🏠 System mode set to: \(mode)")
    }
    
    // MARK: - Private Helpers
    
    private func parseAssessment(from jsonString: String) throws -> SecurityAssessment {
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NovinIntelligenceError.processingFailed("Invalid JSON response")
        }
        
        // Extract fields from response
        guard let threatLevelString = json["threatLevel"] as? String,
              let threatLevel = ThreatLevel(rawValue: threatLevelString),
              let confidence = json["confidence"] as? Double,
              let processingTimeMs = json["processingTimeMs"] as? Double,
              let reasoning = json["reasoning"] as? String else {
            throw NovinIntelligenceError.processingFailed("Missing required fields in response")
        }
        
        let requestId = json["requestId"] as? String
        let timestamp = json["timestamp"].flatMap { "\($0)" }
        
        return SecurityAssessment(
            threatLevel: threatLevel,
            confidence: confidence,
            processingTimeMs: processingTimeMs,
            reasoning: reasoning,
            requestId: requestId,
            timestamp: timestamp
        )
    }
    
    /// Assess a motion event
    public func assessMotion(confidence: Double, location: String = "unknown") async throws -> SecurityAssessment {
        let motionJson = """
        {
            "type": "motion",
            "confidence": \(confidence),
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "\(location)",
                "sensor_type": "motion_detector",
                "home_mode": "standard"
            }
        }
        """
        
        return try await assess(requestJson: motionJson)
    }

    /// Assess motion and return PI-format JSON
    public func assessMotionPI(confidence: Double, location: String = "unknown") async throws -> String {
        let result = try await assessMotion(confidence: confidence, location: location)
        return try result.toPI()
    }
    
    /// Assess a door event
    public func assessDoorEvent(isOpening: Bool, location: String = "frontDoor") async throws -> SecurityAssessment {
        let doorJson = """
        {
            "type": "door_motion",
            "confidence": 0.9,
            "timestamp": \(Date().timeIntervalSince1970),
            "metadata": {
                "location": "\(location)",
                "motion_type": "\(isOpening ? "opening" : "closing")",
                "sensor_type": "contact_sensor",
                "home_mode": "standard"
            }
        }
        """
        
        return try await assess(requestJson: doorJson)
    }

    /// Assess door event and return PI-format JSON
    public func assessDoorEventPI(isOpening: Bool, location: String = "frontDoor") async throws -> String {
        let result = try await assessDoorEvent(isOpening: isOpening, location: location)
        return try result.toPI()
    }

    // MARK: - Math + Rules helpers
    private func mapScoreToThreatLevel(_ score: Double) -> ThreatLevel {
        switch score {
        case 0.9...1.0: return .critical
        case 0.7..<0.9: return .elevated
        case 0.4..<0.7: return .standard
        default: return .low
        }
    }

    private func buildExplanation(
        fused: IntelligentFusion.FusionResult,
        rules: ReasoningSwift.Result,
        chainPattern: EventChainAnalyzer.ChainPattern?,
        motionAnalysis: String?,
        zoneRiskScore: Double
    ) -> String {
        var parts: [String] = []
        parts.append("Assessment: \(mapScoreToThreatLevel(fused.finalScore).rawValue.uppercased())")
        
        // Chain pattern
        if let chain = chainPattern {
            parts.append("Chain: \(chain.name) (\(chain.reasoning))")
        }
        
        // Motion analysis
        if let motion = motionAnalysis {
            parts.append("Motion: \(motion)")
        }
        
        // Zone risk
        parts.append("Zone Risk: \(String(format: "%.0f", zoneRiskScore * 100))%")
        
        // Top math evidence by weight
        let top = fused.explanation.sorted { $0.weight > $1.weight }.prefix(3)
        if !top.isEmpty {
            let desc = top.map { "\($0.name): \($0.present > 0.5 ? "STRONG" : "WEAK")" }.joined(separator: ", ")
            parts.append("Math: \(desc)")
        }
        if !rules.factors.isEmpty {
            let names = rules.factors.prefix(3)
            parts.append("Rules: \(names.joined(separator: ", "))")
        }
        parts.append("Bayes: \(String(format: "%.0f", fused.bayesianContribution*100))% | Rules: \(String(format: "%.0f", fused.ruleContribution*100))%")
        parts.append("Confidence: \(String(format: "%.0f", fused.confidence*100))%")
        parts.append("Final: \(String(format: "%.1f", fused.finalScore*100))% threat probability")
        return parts.joined(separator: " | ")
    }
}
