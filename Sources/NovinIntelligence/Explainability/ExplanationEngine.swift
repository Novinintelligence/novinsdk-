import Foundation

/// Enterprise AI: Human-like explanation generation
/// Adaptive, context-aware, personalized reasoning
@available(iOS 15.0, macOS 12.0, *)
public struct ExplanationEngine {
    
    // MARK: - Types
    
    public struct PersonalizedExplanation {
        public let summary: String              // Short, human-readable summary
        public let reasoning: String            // Detailed "why" explanation
        public let context: [String]            // Contextual factors considered
        public let recommendation: String       // What user should know/do
        public let tone: ExplanationTone        // How it's communicated
        
        public enum ExplanationTone {
            case reassuring     // "Nothing to worry about"
            case informative    // "Here's what's happening"
            case alerting       // "Something unusual detected"
            case urgent         // "Immediate attention needed"
        }
    }
    
    // MARK: - Main API
    
    /// Generate personalized, adaptive explanation
    public static func explain(
        threatLevel: ThreatLevel,
        chainPattern: EventChainAnalyzer.ChainPattern?,
        motionAnalysis: MotionAnalyzer.MotionFeatures?,
        zone: ZoneClassifier.Zone,
        timeContext: TimeContext,
        userPatterns: UserPatterns,
        eventType: String,
        homeMode: String
    ) -> PersonalizedExplanation {
        
        // Determine tone based on threat level
        let tone = determineTone(threatLevel: threatLevel, chainPattern: chainPattern)
        
        // Build adaptive summary
        let summary = buildSummary(
            threatLevel: threatLevel,
            chainPattern: chainPattern,
            motionAnalysis: motionAnalysis,
            zone: zone,
            timeContext: timeContext,
            homeMode: homeMode
        )
        
        // Build detailed reasoning
        let reasoning = buildReasoning(
            threatLevel: threatLevel,
            chainPattern: chainPattern,
            motionAnalysis: motionAnalysis,
            zone: zone,
            timeContext: timeContext,
            userPatterns: userPatterns,
            eventType: eventType,
            homeMode: homeMode
        )
        
        // Extract contextual factors
        let context = buildContext(
            chainPattern: chainPattern,
            motionAnalysis: motionAnalysis,
            zone: zone,
            timeContext: timeContext,
            userPatterns: userPatterns
        )
        
        // Generate personalized recommendation
        let recommendation = buildRecommendation(
            threatLevel: threatLevel,
            chainPattern: chainPattern,
            zone: zone,
            timeContext: timeContext,
            homeMode: homeMode
        )
        
        return PersonalizedExplanation(
            summary: summary,
            reasoning: reasoning,
            context: context,
            recommendation: recommendation,
            tone: tone
        )
    }
    
    // MARK: - Tone Detection
    
    private static func determineTone(
        threatLevel: ThreatLevel,
        chainPattern: EventChainAnalyzer.ChainPattern?
    ) -> PersonalizedExplanation.ExplanationTone {
        
        // Urgent: Active break-in or critical threats
        if threatLevel == .critical || chainPattern?.name == "active_break_in" {
            return .urgent
        }
        
        // Alerting: Elevated threats or intrusion patterns
        if threatLevel == .elevated || chainPattern?.name == "intrusion_sequence" {
            return .alerting
        }
        
        // Reassuring: Likely false positive or normal activity
        if chainPattern?.name == "package_delivery" || threatLevel == .low {
            return .reassuring
        }
        
        // Informative: Standard monitoring
        return .informative
    }
    
    // MARK: - Summary Builder
    
    private static func buildSummary(
        threatLevel: ThreatLevel,
        chainPattern: EventChainAnalyzer.ChainPattern?,
        motionAnalysis: MotionAnalyzer.MotionFeatures?,
        zone: ZoneClassifier.Zone,
        timeContext: TimeContext,
        homeMode: String
    ) -> String {
        
        // Chain pattern takes priority
        if let pattern = chainPattern {
            switch pattern.name {
            case "package_delivery":
                return "📦 Likely a package delivery at your \(zone.name.replacingOccurrences(of: "_", with: " "))"
                
            case "intrusion_sequence":
                return "⚠️ Unusual activity pattern detected at \(zone.name.replacingOccurrences(of: "_", with: " "))"
                
            case "forced_entry":
                return "🚨 Possible forced entry attempt at \(zone.name.replacingOccurrences(of: "_", with: " "))"
                
            case "active_break_in":
                return "🚨 ALERT: Active break-in detected at \(zone.name.replacingOccurrences(of: "_", with: " "))"
                
            case "prowler_activity":
                return "👁️ Someone moving around your property perimeter"
                
            default:
                break
            }
        }
        
        // Motion-based summaries
        if let motion = motionAnalysis {
            let location = zone.name.replacingOccurrences(of: "_", with: " ")
            
            switch motion.activityType {
            case .package_drop:
                return "📦 Brief activity at \(location) - likely a delivery"
            case .pet:
                return "🐾 Pet movement detected at \(location)"
            case .loitering:
                return "👤 Someone lingering near \(location)"
            case .walking:
                return "🚶 Person walking past \(location)"
            case .running:
                return "🏃 Fast movement detected at \(location)"
            case .vehicle:
                return "🚗 Vehicle activity near \(location)"
            case .stationary:
                return "📍 Minor movement at \(location)"
            case .unknown:
                break
            }
        }
        
        // Time-based context
        let timePhrase = timeContext.isNight ? "Night activity" : 
                        timeContext.isDeliveryWindow ? "Daytime activity" : "Activity"
        let locationPhrase = zone.name.replacingOccurrences(of: "_", with: " ")
        
        // Threat-based fallback
        switch threatLevel {
        case .critical:
            return "🚨 URGENT: \(timePhrase) at \(locationPhrase) needs immediate attention"
        case .elevated:
            return "⚠️ \(timePhrase) at \(locationPhrase) requires your attention"
        case .standard:
            return "ℹ️ \(timePhrase) detected at \(locationPhrase)"
        case .low:
            return "✓ Normal \(timePhrase.lowercased()) at \(locationPhrase)"
        }
    }
    
    // MARK: - Reasoning Builder
    
    private static func buildReasoning(
        threatLevel: ThreatLevel,
        chainPattern: EventChainAnalyzer.ChainPattern?,
        motionAnalysis: MotionAnalyzer.MotionFeatures?,
        zone: ZoneClassifier.Zone,
        timeContext: TimeContext,
        userPatterns: UserPatterns,
        eventType: String,
        homeMode: String
    ) -> String {
        
        var reasons: [String] = []
        
        // 1. Event chain reasoning
        if let pattern = chainPattern {
            switch pattern.name {
            case "package_delivery":
                reasons.append("I detected a doorbell ring followed by brief motion, then silence. This pattern matches \(Int(pattern.confidence * 100))% with typical package deliveries.")
                reasons.append("The quick in-and-out behavior suggests someone dropped something off rather than lingering.")
                
            case "intrusion_sequence":
                reasons.append("I noticed motion leading to a door event, followed by continued movement. This sequence is concerning because it suggests purposeful entry.")
                reasons.append("Unlike a delivery, the activity didn't stop after the door event - someone may have entered.")
                
            case "forced_entry":
                reasons.append("Multiple door or window events in a short time (less than 15 seconds) caught my attention.")
                reasons.append("This rapid repetition typically indicates someone trying to force entry, not normal access.")
                
            case "active_break_in":
                reasons.append("Glass breaking followed immediately by motion is a classic break-in signature.")
                reasons.append("The timing and sequence strongly suggest forced entry in progress.")
                
            case "prowler_activity":
                reasons.append("I tracked movement across multiple zones of your property within a minute.")
                reasons.append("This perimeter reconnaissance pattern suggests someone scoping out your home.")
                
            default:
                break
            }
        }
        
        // 2. Motion analysis reasoning
        if let motion = motionAnalysis {
            switch motion.activityType {
            case .package_drop:
                reasons.append("The motion lasted only \(Int(motion.duration)) seconds with low energy - typical of someone quickly placing a package.")
                
            case .pet:
                reasons.append("The erratic, low-intensity movement pattern matches pet behavior (\(Int(motion.confidence * 100))% confidence).")
                
            case .loitering:
                reasons.append("Activity continued for over 30 seconds with sustained but moderate energy - someone appears to be waiting or watching.")
                
            case .walking:
                reasons.append("Steady, medium-energy movement suggests normal pedestrian activity.")
                
            case .running:
                reasons.append("High-energy, fast movement detected - someone moving quickly through the area.")
                
            case .vehicle:
                reasons.append("Very high energy signature consistent with vehicle movement.")
                
            default:
                break
            }
        }
        
        // 3. Zone-based reasoning
        switch zone.type {
        case .entry:
            reasons.append("Your \(zone.name.replacingOccurrences(of: "_", with: " ")) is a primary access point - any activity here gets elevated scrutiny.")
            
        case .perimeter:
            reasons.append("Activity at the \(zone.name.replacingOccurrences(of: "_", with: " ")) could indicate someone approaching your entry points.")
            
        case .interior:
            if homeMode == "away" {
                reasons.append("Motion inside your home while you're away is highly unusual and concerning.")
            } else {
                reasons.append("Interior motion while you're home is expected normal activity.")
            }
            
        case .publicArea:
            reasons.append("The \(zone.name.replacingOccurrences(of: "_", with: " ")) is a public area - activity here is typically less concerning.")
            
        default:
            break
        }
        
        // 4. Time context reasoning
        if timeContext.isNight {
            if homeMode == "away" {
                reasons.append("Night activity while you're away raises the threat level - most legitimate visitors come during the day.")
            } else {
                reasons.append("It's nighttime, so I'm being more vigilant, but this could still be routine activity.")
            }
        } else if timeContext.isDeliveryWindow {
            reasons.append("It's during typical delivery hours (\(timeContext.deliveryWindowStart)AM-\(timeContext.deliveryWindowEnd)PM), which makes delivery activity more likely.")
        }
        
        // 5. User pattern reasoning
        let deliveryFreq = userPatterns.deliveryFrequency
        if deliveryFreq > 0.5 {
            reasons.append("You receive deliveries frequently, so I've learned to recognize delivery patterns at your home.")
        }
        
        if let fpCount = userPatterns.falsePositiveHistory[eventType], fpCount > 3 {
            reasons.append("You've marked similar \(eventType) events as false alarms before, so I'm being less aggressive.")
        }
        
        // 6. Home mode reasoning
        if homeMode == "away" {
            reasons.append("Your home is in away mode, which means any activity gets elevated attention.")
        } else if homeMode == "home" {
            reasons.append("You're home, so I expect some normal activity - I'm filtering out routine movements.")
        }
        
        // Combine all reasoning
        return reasons.joined(separator: " ")
    }
    
    // MARK: - Context Builder
    
    private static func buildContext(
        chainPattern: EventChainAnalyzer.ChainPattern?,
        motionAnalysis: MotionAnalyzer.MotionFeatures?,
        zone: ZoneClassifier.Zone,
        timeContext: TimeContext,
        userPatterns: UserPatterns
    ) -> [String] {
        
        var context: [String] = []
        
        if let pattern = chainPattern {
            context.append("Event sequence: \(pattern.name.replacingOccurrences(of: "_", with: " "))")
        }
        
        if let motion = motionAnalysis {
            context.append("Motion type: \(motion.activityType.rawValue.replacingOccurrences(of: "_", with: " "))")
            context.append("Duration: \(Int(motion.duration))s")
        }
        
        context.append("Location: \(zone.name.replacingOccurrences(of: "_", with: " ")) (\(zone.type.rawValue.replacingOccurrences(of: "Area", with: " area")))")
        
        if timeContext.isNight {
            context.append("Time: Night (\(timeContext.currentHour):00)")
        } else if timeContext.isDeliveryWindow {
            context.append("Time: Delivery window (\(timeContext.currentHour):00)")
        } else {
            context.append("Time: \(timeContext.currentHour):00")
        }
        
        if userPatterns.deliveryFrequency > 0.5 {
            context.append("Delivery patterns: Frequent")
        }
        
        return context
    }
    
    // MARK: - Recommendation Builder
    
    private static func buildRecommendation(
        threatLevel: ThreatLevel,
        chainPattern: EventChainAnalyzer.ChainPattern?,
        zone: ZoneClassifier.Zone,
        timeContext: TimeContext,
        homeMode: String
    ) -> String {
        
        // Critical/urgent situations
        if threatLevel == .critical || chainPattern?.name == "active_break_in" {
            return "🚨 Check your camera immediately and consider calling authorities. This appears to be an active security incident."
        }
        
        if chainPattern?.name == "forced_entry" {
            return "⚠️ Verify your security - check if doors/windows are secure. This may be an entry attempt."
        }
        
        // Elevated situations
        if threatLevel == .elevated {
            if chainPattern?.name == "intrusion_sequence" {
                return "👁️ Review your camera footage. If you're not expecting anyone, this warrants attention."
            }
            if chainPattern?.name == "prowler_activity" {
                return "🔍 Someone is moving around your property. Check your cameras to identify who it is."
            }
            return "ℹ️ Check your cameras when convenient - this activity is worth reviewing."
        }
        
        // Reassuring situations
        if chainPattern?.name == "package_delivery" {
            if homeMode == "away" {
                return "📦 Likely a delivery. Check for packages when you return home."
            } else {
                return "📦 Your delivery has probably arrived - check your \(zone.name.replacingOccurrences(of: "_", with: " "))."
            }
        }
        
        // Low threat
        if threatLevel == .low {
            return "✓ This appears normal. No action needed, but feel free to review footage if curious."
        }
        
        // Standard monitoring
        return "ℹ️ Normal monitoring active. Review camera footage if you want more details about this activity."
    }
    
    // MARK: - Supporting Types
    
    public struct TimeContext {
        public let currentHour: Int
        public let isNight: Bool
        public let isDeliveryWindow: Bool
        public let deliveryWindowStart: Int
        public let deliveryWindowEnd: Int
        
        public init(currentHour: Int, isNight: Bool, isDeliveryWindow: Bool, deliveryWindowStart: Int, deliveryWindowEnd: Int) {
            self.currentHour = currentHour
            self.isNight = isNight
            self.isDeliveryWindow = isDeliveryWindow
            self.deliveryWindowStart = deliveryWindowStart
            self.deliveryWindowEnd = deliveryWindowEnd
        }
    }
}



