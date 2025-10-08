import Foundation
import os.log
/// Main NovinIntelligence SDK class - Enterprise Edition
@available(iOS 15.0, macOS 12.0, *)
public final class NovinIntelligence: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = NovinIntelligence()

    // MARK: - State
    private var isInitialized = false
    private var initTask: Task<Void, Error>? = nil
{{ ... }}
    // MARK: - Initialization
    
    /// Initialize the NovinIntelligence SDK with enterprise features
    /// - Parameter brandConfig: Optional brand-specific configuration
    public func initialize(brandConfig: String? = nil) async throws {
        // Fast path: already initialized
        if isInitialized { return }

        // If an initialization is already in progress, await it
        if let existing = initTask {
            try await existing.value
            return
        }
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

        // Publish the task so concurrent callers can await it
        initTask = task
        do {
            try await task.value
        } catch {
            // Reset on failure so a later call can retry
            initTask = nil
            throw error
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
                    // Fuzzy + beliefs (P1)
                    var fuzzyThreat: Double = -1
                    var fuzzyIntent: String = ""
                    var fuzzyIntentScores: [String: Double] = [:]
                    var fuzzyRules: [String] = []
                    var beliefPrev: [String: Double] = [:]
                    var beliefNew: [String: Double] = [:]
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

                        // Fuzzy micro-kernel (duration/energy from metadata if present)
                        let duration = analyzed.duration
                        let energy = analyzed.energy
                        // Home mode + activity hint
                        let homeMode = (metadata["home_mode"] as? String) ?? "home"
                        let activityHint = (metadata["activity"] as? String)
                        // Event hour from event timestamp (P1: use event timestamp, not wall clock)
                        let cfg = self.getTemporalConfiguration()
                        var cal = Calendar(identifier: .gregorian)
                        cal.timeZone = cfg.timezone
                        let eventTs = (request["timestamp"] as? Double) ?? Date().timeIntervalSince1970
                        let eventHour = cal.component(.hour, from: Date(timeIntervalSince1970: eventTs))

                        let fuzzy = MotionAnalyzer.fuzzyAssess(
                            duration: duration,
                            energy: energy,
                            zoneRisk: zoneRiskScore,
                            eventHour: eventHour,
                            homeMode: homeMode,
                            activityHint: activityHint
                        )
                        fuzzyThreat = fuzzy.threat
                        fuzzyIntent = fuzzy.intent
                        fuzzyIntentScores = fuzzy.intentScores
                        fuzzyRules = fuzzy.rules

                        // Minimal belief update (P1): accumulate evidence across events
                        // Map fuzzy intents to hypotheses and add chain/intrusion signal if present later
                        var evidence: [String: Double] = [:]
                        evidence["delivery"] = fuzzyIntentScores["delivery"] ?? 0.0
                        evidence["prowler"] = fuzzyIntentScores["prowler"] ?? 0.0
                        evidence["pet"] = fuzzyIntentScores["pet"] ?? 0.0
                        // intrusion evidence will be finalized after chain pattern detection below
                        // For now, seed with fraction of prowler likelihood
                        evidence["intrusion"] = max(0.0, (fuzzyIntentScores["prowler"] ?? 0.0) * 0.5)

                        let key = (metadata["location"] as? String) ?? "unknown"
                        let update = self.beliefStore.update(key: key, evidence: evidence)
                        beliefPrev = update.prev
                        beliefNew = update.next
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

                    // 4.1) FEAR-Chain safety adjustment (training-free, lightweight)
                    var fearScore: Double = 0.0
                    var normality: Double = 0.0
                    var safetyAdjustmentVal: Double = 0.0
                    if self.reasoningConfig.enableFearChain {
                        fearScore = self.fearHeuristic.score(features: features)
                        // Compute normality against running mean BEFORE update
                        normality = self.normalityTracker.score(features: features)
                        // Update statistics for next observations (online, no training)
                        self.normalityTracker.update(features: features)
                        // Conservative weights: amplify threat slightly, dampen by normality
                        let alpha = 0.15
                        let beta = 0.10
                        safetyAdjustmentVal = alpha * fearScore - beta * normality
                        finalScore += safetyAdjustmentVal
                    }

                    // Pet-in-home dampening (P1)
                    if let metadata = request["metadata"] as? [String: Any] {
                        let homeMode = (metadata["home_mode"] as? String) ?? "home"
                        if homeMode == "home" {
                            // If fuzzy intent is pet with meaningful weight, dampen
                            let petWeight = fuzzyIntentScores["pet"] ?? 0.0
                            if petWeight > 0.4 {
                                let cfg = self.getTemporalConfiguration()
                                finalScore = finalScore * (1.0 - min(1.0, max(0.0, cfg.petDampeningFactor)))
                            }
                        }
                    }

                    finalScore = max(0.0, min(1.0, finalScore))
                    
                    // 5) Optional symbolic planning (training-free, behind flags)
                    var combinedPlan: Plan? = nil
                    if self.reasoningConfig.enableSymbolicPlanner || self.reasoningConfig.enableAffordancePlanner {
                        // Build initial world from features via translator
                        let preds = self.symbolicTranslator.translate(features: features, request: request)
                        let world = WorldStateGraph()
                        for p in preds { world.addPredicate(p) }

                        var steps: [Action] = []
                        if self.reasoningConfig.enableAffordancePlanner {
                            let metadata = request["metadata"] as? [String: Any]
                            let ap = self.affordancePlanner.suggest(features: features, metadata: metadata)
                            steps.append(contentsOf: ap.steps)
                        }
                        if self.reasoningConfig.enableSymbolicPlanner {
                            let sp = self.symbolicPlanner.plan(initial: world, goalDescription: [Predicate("stage_act")], maxNodes: 128)
                            steps.append(contentsOf: sp.steps)
                        }
                        combinedPlan = Plan(steps: steps, estimatedCost: Double(steps.count))
                    }

                    // 5.1) Environmental mirror (optional)
                    var mirrorSummary: String? = nil
                    if self.reasoningConfig.enableEnvironmentalMirror {
                        // Predicted predicates from fused evidence
                        var predicted = self.buildPredictedPredicates(from: fused)
                        // Observed predicates from translator
                        let observedSet = Set(self.symbolicTranslator.translate(features: features, request: request))
                        let diff = self.environmentalMirror.diff(predicted: predicted, observed: observedSet)
                        let missingCount = diff.missingPredicates.count
                        let unexpectedCount = diff.unexpectedPredicates.count
                        var updatesCount = 0
                        if missingCount > 0 || unexpectedCount > 0 {
                            let updates = self.symbolicUpdater.proposeUpdates(diff: diff)
                            updatesCount = updates.count
                            let missing = diff.missingPredicates.map { $0.name }.joined(separator: ", ")
                            let unexpected = diff.unexpectedPredicates.map { $0.name }.joined(separator: ", ")
                            let updateHints = updates.map { $0.description }.joined(separator: "; ")
                            mirrorSummary = "Mirror mismatch: missing=[\(missing)] unexpected=[\(unexpected)] | Updates: \(updateHints)"

                            // Apply updates in-memory if enabled
                            if self.applyMirrorUpdates {
                                // Persist sets for future assessments (process lifetime only)
                                for p in diff.missingPredicates { self.mirrorAddedPredicates.insert(p.name) }
                                for p in diff.unexpectedPredicates { self.mirrorSuppressedPredicates.insert(p.name) }
                            }
                        } else {
                            mirrorSummary = "Mirror: predicted matches observed"
                        }

                        // Telemetry
                        MirrorTelemetry.shared.record(missing: missingCount, unexpected: unexpectedCount, updates: updatesCount, durationMs: 0)
                    }

                    // 6) Map and build assessment
                    let level = self.mapScoreToThreatLevel(finalScore)
                    var reasoning = self.buildExplanation(
                        fused: fused,
                        rules: ruleResult,
                        chainPattern: chainPattern,
                        motionAnalysis: motionAnalysis,
                        zoneRiskScore: zoneRiskScore,
                        plan: combinedPlan,
                        mirror: mirrorSummary
                    )
                    // Append fuzzy and belief trace for transparency (P1)
                    var traceParts: [String] = []
                    if fuzzyThreat >= 0 {
                        traceParts.append("Fuzzy: intent=\(fuzzyIntent) threat=\(String(format: "%.2f", fuzzyThreat)) rules=\(fuzzyRules.prefix(2).joined(separator: ","))")
                    }
                    if !beliefNew.isEmpty {
                        func pct(_ x: Double?) -> String { String(format: "%.0f%%", (x ?? 0)*100) }
                        let deltaIntr = (beliefNew["intrusion"] ?? 0) - (beliefPrev["intrusion"] ?? 0)
                        traceParts.append("Beliefs: deliv=\(pct(beliefNew["delivery"])) intr=\(pct(beliefNew["intrusion"])) (Δ=\(String(format: "%.0f%%", deltaIntr*100))) prowler=\(pct(beliefNew["prowler"])) pet=\(pct(beliefNew["pet"]))")
                    }
                    if !traceParts.isEmpty { reasoning += " | " + traceParts.joined(separator: " | ") }
                    
                    // 6) Generate personalized, adaptive explanation
                    let zone = self.zoneClassifier.classifyLocation(
                        (request["metadata"] as? [String: Any])?["location"] as? String ?? "unknown"
                    )
                    let config = self.getTemporalConfiguration()
                    // P1: Time context from EVENT TIMESTAMP (not wall clock)
                    var calendarWithTZ = Calendar(identifier: .gregorian)
                    calendarWithTZ.timeZone = config.timezone
                    let eventTs = (request["timestamp"] as? Double) ?? Date().timeIntervalSince1970
                    let eventDate = Date(timeIntervalSince1970: eventTs)
                    let currentHour = calendarWithTZ.component(.hour, from: eventDate)
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
                            "zone_risk": zoneRiskScore,
                            "fuzzy_threat": (fuzzyThreat >= 0 ? fuzzyThreat : 0.0),
                            "belief_delivery": beliefNew["delivery"] ?? 0.0,
                            "belief_intrusion": beliefNew["intrusion"] ?? 0.0,
                            "belief_prowler": beliefNew["prowler"] ?? 0.0,
                            "belief_pet": beliefNew["pet"] ?? 0.0,
                            "fear": self.reasoningConfig.enableFearChain ? fearScore : 0.0,
                            "normality": self.reasoningConfig.enableFearChain ? normality : 0.0,
                            "safety_adjustment": self.reasoningConfig.enableFearChain ? safetyAdjustmentVal : 0.0,
                            "mirror_missing": self.reasoningConfig.enableEnvironmentalMirror ? Double(MirrorTelemetry.shared.lastMissing) : 0.0,
                            "mirror_unexpected": self.reasoningConfig.enableEnvironmentalMirror ? Double(MirrorTelemetry.shared.lastUnexpected) : 0.0,
                            "mirror_updates": self.reasoningConfig.enableEnvironmentalMirror ? Double(MirrorTelemetry.shared.lastUpdates) : 0.0
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
        zoneRiskScore: Double,
        plan: Plan?,
        mirror: String?
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

        // Optional plan steps
        if let plan = plan, !plan.steps.isEmpty {
            let stepNames = plan.steps.map { $0.name }.joined(separator: " → ")
            parts.append("Plan: \(stepNames)")
        }
        // Optional mirror summary
        if let mirror = mirror { parts.append(mirror) }
        
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

    // MARK: - Phase 4 helpers
    private func buildPredictedPredicates(from fused: IntelligentFusion.FusionResult) -> Set<Predicate> {
        var set: Set<Predicate> = []
        // Include starting planner stage to align with translator's observed seeds
        set.insert(Predicate("stage_observe"))
        for e in fused.explanation where e.present > 0.5 {
            // Map evidence factor names to canonical predicate names
            let name = e.name
            set.insert(Predicate(name))
        }
        // Apply in-memory mirror adjustments if any
        for a in mirrorAddedPredicates { set.insert(Predicate(a)) }
        for s in mirrorSuppressedPredicates { set.remove(Predicate(s)) }
        return set
    }
}
