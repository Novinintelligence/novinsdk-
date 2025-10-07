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
            homeMode: homeMode,
            eventType: eventType,
            userPatterns: userPatterns
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
        homeMode: String,
        eventType: String,
        userPatterns: UserPatterns
    ) -> String {
        
        // Chain pattern takes priority with deeper reasoning and chain influence
        if let pattern = chainPattern {
            var baseSummary = ""
            switch pattern.name {
            case "package_delivery":
                baseSummary = "📦 This appears to be a package delivery at your \(zone.name.replacingOccurrences(of: "_", with: " ")) because the brief motion followed a doorbell event, matching typical delivery patterns."
                
            case "intrusion_sequence":
                baseSummary = "⚠️ The sequence of events at \(zone.name.replacingOccurrences(of: "_", with: " ")) suggests someone may be attempting to enter, as motion led to a door event without stopping."
                
            case "forced_entry":
                baseSummary = "🚨 Rapid repeated events at \(zone.name.replacingOccurrences(of: "_", with: " ")) indicate someone trying to force entry, not normal access."
                
            case "active_break_in":
                baseSummary = "🚨 ALERT: Glass breaking followed immediately by motion at \(zone.name.replacingOccurrences(of: "_", with: " ")) signals an active break-in in progress."
                
            case "prowler_activity":
                baseSummary = "👁️ Movement across multiple zones suggests someone is scoping your property perimeter at \(zone.name.replacingOccurrences(of: "_", with: " "))."
                
            default:
                break
            }
            // Add user pattern context if chain is influenced by past behaviors
            if userPatterns.deliveryFrequency > 0.5 && pattern.name == "package_delivery" {
                baseSummary += " My learning from your frequent deliveries helped recognize this pattern."
            }
            if let fpCount = userPatterns.falsePositiveHistory[eventType], fpCount > 3 {
                baseSummary += " Though similar events have been false alarms before, this chain still warrants attention."
            }
            return baseSummary
        }
        
        // Motion-based summaries with deeper reasoning and user context
        if let motion = motionAnalysis {
            let location = zone.name.replacingOccurrences(of: "_", with: " ")
            
            var baseSummary = ""
            switch motion.activityType {
            case .package_drop:
                baseSummary = "📦 Brief activity at \(location) appears to be a delivery based on the short duration motion, suggesting someone dropped something off rather than lingering."
            case .pet:
                baseSummary = "🐾 Pet movement detected at \(location) due to erratic, low-intensity patterns that don't match human behavior."
            case .loitering:
                baseSummary = "👤 Someone is lingering near \(location) for over 30 seconds with sustained moderate energy, suggesting they may be waiting or observing."
            case .walking:
                baseSummary = "🚶 Person walking past \(location) with steady medium-energy movement, indicating normal pedestrian activity."
            case .running:
                baseSummary = "🏃 Fast movement detected at \(location) because someone is moving quickly, which could indicate urgency or avoidance."
            case .vehicle:
                baseSummary = "🚗 Vehicle activity near \(location) detected with high energy signature, consistent with automotive movement."
            case .stationary:
                baseSummary = "📍 Minor movement at \(location) with low activity level, suggesting something small or distant."
            case .unknown:
                break
            }
            
            // Add user pattern context for intuition
            if userPatterns.deliveryFrequency > 0.5 && motion.activityType == .package_drop {
                baseSummary += " My learning from your frequent deliveries helps confirm this."
            }
            if let fpCount = userPatterns.falsePositiveHistory[eventType], fpCount > 3 {
                baseSummary += " Similar motion events have been false alarms before."
            }
            if timeContext.isNight && homeMode == "away" {
                baseSummary += " Night activity while away often raises concerns, but this seems normal."
            }
            
            return baseSummary
        }
        
        // Threat-based fallback with deeper reasoning based on event type and user patterns
        let locationPhrase = zone.name.replacingOccurrences(of: "_", with: " ")
        let timePhrase = timeContext.isNight ? "nighttime" : timeContext.isDeliveryWindow ? "daytime delivery hours" : "daytime"
        
        var summary = ""
        switch threatLevel {
        case .critical:
            summary = "🚨 URGENT: \(eventType.capitalized) activity at \(locationPhrase) during \(timePhrase) indicates a high-threat situation requiring immediate response."
        case .elevated:
            summary = "⚠️ \(eventType.capitalized) activity at \(locationPhrase) during \(timePhrase) has elevated security concerns that warrant your attention."
        case .standard:
            summary = "ℹ️ \(eventType.capitalized) activity at \(locationPhrase) during \(timePhrase) is standard and being monitored for any changes."
        case .low:
            summary = "✓ Normal \(eventType.lowercased()) activity at \(locationPhrase) during \(timePhrase) appears routine and not concerning."
        }
        
        // Add user pattern context for intuition
        if userPatterns.deliveryFrequency > 0.5 && eventType == "motion" {
            summary += " My learning from your frequent deliveries helps distinguish normal activity."
        }
        if let fpCount = userPatterns.falsePositiveHistory[eventType], fpCount > 3 {
            summary += " Similar events have been false alarms before, so I'm being less aggressive."
        }
        if timeContext.isNight && homeMode == "away" {
            summary += " Night activity while away often raises concerns, but this seems normal."
        }
        
        return summary
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



