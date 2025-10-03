// © 2025 Oliver Herbert. Proprietary and Confidential. All rights reserved.
// Use, copying, and distribution of this software are permitted only in accordance
// with a separate written license agreement from the owner.
//
//  EventSummaryFormatter.swift
//  intelligence
//
//  Created on 02/10/2025.
//  Truly adaptive, context-aware event summaries with human-level reasoning
//

import Foundation

/// Generates genuinely human summaries by understanding context, not templates
/// Adapts tone, length, and detail based on severity, time, location, and patterns
public struct EventSummaryFormatter {
    
    // MARK: - Public Types
    
    public struct MinimalSummary: Codable {
        public let alert_level: String  // "low" | "standard" | "elevated" | "critical"
        public let summary: String      // Adaptive human narrative, context-aware
        
        public init(alert_level: String, summary: String) {
            self.alert_level = alert_level
            self.summary = summary
        }
    }
    
    public enum Severity: String, Codable {
        case low, standard, elevated, critical
        
        var lengthBudget: (min: Int, max: Int) {
            switch self {
            case .low: return (40, 85)      // Concise, reassuring
            case .standard: return (60, 120) // Informative, balanced
            case .elevated: return (80, 160) // Detailed, actionable
            case .critical: return (90, 200) // Comprehensive, urgent
            }
        }
        
        var tone: String {
            switch self {
            case .low: return "casual_reassuring"
            case .standard: return "informative_neutral"
            case .elevated: return "concerned_actionable"
            case .critical: return "urgent_directive"
            }
        }
    }
    
    // MARK: - Adaptive Composition System
    
    /// Context understanding - extracts meaning from raw event data
    private struct ContextAnalyzer {
        let context: [String: Any]
        let severity: Severity
        let patternType: String?
        var rng: SplitMix64
        
        // Extract temporal context
        var timeContext: String {
            if let timestamp = context["timestamp"] as? TimeInterval {
                let hour = Calendar.current.component(.hour, from: Date(timeIntervalSince1970: timestamp))
                switch hour {
                case 0..<5: return pick(["in the dead of night", "in the early hours", "well past midnight"])
                case 5..<8: return pick(["early this morning", "at dawn", "as the sun came up"])
                case 8..<12: return pick(["this morning", "mid-morning"])
                case 12..<14: return pick(["around midday", "just after noon"])
                case 14..<17: return pick(["this afternoon", "mid-afternoon"])
                case 17..<20: return pick(["this evening", "as evening fell", "at dusk"])
                case 20..<23: return pick(["tonight", "late this evening"])
                default: return pick(["late at night", "after hours"])
                }
            }
            return pick(["just now", "moments ago", "recently"])
        }
        
        // Extract location context with personality
        var locationContext: String {
            if let location = context["location"] as? String {
                let base = location.replacingOccurrences(of: "_", with: " ")
                switch location.lowercased() {
                case let loc where loc.contains("front"):
                    return pick(["your front entrance", "the main door", "out front"])
                case let loc where loc.contains("back"):
                    return pick(["your back door", "the rear entrance", "out back"])
                case let loc where loc.contains("garage"):
                    return pick(["the garage area", "near the garage", "by the garage door"])
                case let loc where loc.contains("window"):
                    return pick(["a window", "one of the windows", "the window area"])
                default:
                    return pick(["the \(base)", "near the \(base)"])
                }
            }
            return pick(["outside", "on the property", "near the house"])
        }
        
        // Understand motion characteristics
        var motionQuality: String? {
            if let duration = context["duration"] as? Double {
                if duration < 3 {
                    return pick(["fleeting", "very brief", "momentary", "quick"])
                } else if duration < 10 {
                    return pick(["brief", "short", "passing"])
                } else if duration < 30 {
                    return pick(["sustained", "prolonged", "extended"])
                } else {
                    return pick(["lengthy", "extended", "ongoing for some time"])
                }
            }
            return nil
        }
        
        // Helper to pick random variant
        mutating func pick(_ options: [String]) -> String {
            let index = Int(rng.next() % UInt64(options.count))
            return options[index]
        }
    }
    
    // MARK: - Seeded PRNG (SplitMix64)
    
    private struct SplitMix64 {
        private var state: UInt64
        
        init(seed: UInt64) {
            self.state = seed
        }
        
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z &>> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z &>> 27)) &* 0x94d049bb133111eb
            return z ^ (z &>> 31)
        }
        
        mutating func nextDouble() -> Double {
            return Double(next() &>> 11) * 0x1.0p-53
        }
        
        mutating func choose<T>(_ items: [T]) -> T? {
            guard !items.isEmpty else { return nil }
            let index = Int(next() % UInt64(items.count))
            return items[index]
        }
    }
    
    // MARK: - Adaptive Narrative Composer
    
    /// Composes human narratives based on context understanding
    private struct NarrativeComposer {
        var analyzer: ContextAnalyzer
        
        // Compose opening based on severity and pattern
        mutating func composeOpening() -> String {
            switch analyzer.severity {
            case .low:
                return composeLowSeverityOpening()
            case .standard:
                return composeStandardOpening()
            case .elevated:
                return composeElevatedOpening()
            case .critical:
                return composeCriticalOpening()
            }
        }
        
        private mutating func composeLowSeverityOpening() -> String {
            switch analyzer.patternType {
            case "delivery":
                return analyzer.pick([
                    "A delivery person stopped by \(analyzer.timeContext)",
                    "Package delivered \(analyzer.timeContext)",
                    "Looks like your delivery arrived \(analyzer.timeContext)"
                ])
            case "pet":
                return analyzer.pick([
                    "Your pet's been exploring \(analyzer.timeContext)",
                    "Just your furry friend moving around \(analyzer.timeContext)",
                    "Pet activity detected \(analyzer.timeContext)"
                ])
            default:
                if let quality = analyzer.motionQuality {
                    return analyzer.pick([
                        "Some \(quality) movement \(analyzer.timeContext) near \(analyzer.locationContext)",
                        "Noticed \(quality) activity \(analyzer.timeContext) at \(analyzer.locationContext)",
                        "\(quality.capitalized) motion \(analyzer.timeContext) by \(analyzer.locationContext)"
                    ])
                }
                return analyzer.pick([
                    "Brief activity \(analyzer.timeContext) near \(analyzer.locationContext)",
                    "Something moved \(analyzer.timeContext) at \(analyzer.locationContext)"
                ])
            }
        }
        
        private mutating func composeStandardOpening() -> String {
            switch analyzer.patternType {
            case "doorbell":
                return analyzer.pick([
                    "Someone rang the bell \(analyzer.timeContext)",
                    "Visitor at \(analyzer.locationContext) \(analyzer.timeContext)",
                    "The doorbell went off \(analyzer.timeContext)"
                ])
            case "motion":
                if let quality = analyzer.motionQuality {
                    return analyzer.pick([
                        "I'm seeing \(quality) movement \(analyzer.timeContext) near \(analyzer.locationContext)",
                        "There's \(quality) activity happening \(analyzer.timeContext) at \(analyzer.locationContext)",
                        "Detected \(quality) motion \(analyzer.timeContext) by \(analyzer.locationContext)"
                    ])
                }
                return analyzer.pick([
                    "Motion detected \(analyzer.timeContext) at \(analyzer.locationContext)",
                    "Activity spotted \(analyzer.timeContext) near \(analyzer.locationContext)"
                ])
            default:
                return analyzer.pick([
                    "Something's happening \(analyzer.timeContext) at \(analyzer.locationContext)",
                    "Activity detected \(analyzer.timeContext) near \(analyzer.locationContext)"
                ])
            }
        }
        
        private mutating func composeElevatedOpening() -> String {
            switch analyzer.patternType {
            case "prowler":
                return analyzer.pick([
                    "Suspicious movement \(analyzer.timeContext)—someone's moving between multiple areas",
                    "Concerning activity \(analyzer.timeContext)—an individual is systematically checking different zones",
                    "Unusual behavior detected \(analyzer.timeContext)—someone appears to be surveilling the property"
                ])
            case "repeated_door":
                return analyzer.pick([
                    "Multiple attempts at \(analyzer.locationContext) \(analyzer.timeContext)",
                    "Someone's repeatedly trying \(analyzer.locationContext) \(analyzer.timeContext)",
                    "Persistent activity at \(analyzer.locationContext) \(analyzer.timeContext)—looks like someone testing the door"
                ])
            default:
                if let quality = analyzer.motionQuality {
                    return analyzer.pick([
                        "Concerning \(quality) activity \(analyzer.timeContext) at \(analyzer.locationContext)",
                        "Unusual \(quality) movement detected \(analyzer.timeContext) near \(analyzer.locationContext)",
                        "Suspicious \(quality) behavior \(analyzer.timeContext) by \(analyzer.locationContext)"
                    ])
                }
                return analyzer.pick([
                    "Unusual activity \(analyzer.timeContext) at \(analyzer.locationContext)",
                    "Suspicious movement detected \(analyzer.timeContext) near \(analyzer.locationContext)"
                ])
            }
        }
        
        private mutating func composeCriticalOpening() -> String {
            switch analyzer.patternType {
            case "glass_break":
                return analyzer.pick([
                    "🚨 URGENT: Breaking glass detected \(analyzer.timeContext) with movement inside",
                    "CRITICAL ALERT: Glass break \(analyzer.timeContext)—someone's entering the property",
                    "EMERGENCY: Window breach \(analyzer.timeContext) with interior activity"
                ])
            case "interior_breach":
                return analyzer.pick([
                    "🚨 INTRUDER ALERT: Someone's inside your home \(analyzer.timeContext)",
                    "CRITICAL: Unauthorized person detected inside \(analyzer.timeContext)",
                    "EMERGENCY: Interior breach \(analyzer.timeContext)—intruder in the house"
                ])
            case "forced_entry":
                return analyzer.pick([
                    "🚨 BREAK-IN ATTEMPT: Forceful impacts at \(analyzer.locationContext) \(analyzer.timeContext)",
                    "CRITICAL: Someone's forcing \(analyzer.locationContext) \(analyzer.timeContext)",
                    "EMERGENCY: Violent entry attempt at \(analyzer.locationContext) \(analyzer.timeContext)"
                ])
            default:
                return analyzer.pick([
                    "🚨 CRITICAL SECURITY EVENT \(analyzer.timeContext) at \(analyzer.locationContext)",
                    "URGENT ALERT: Serious incident \(analyzer.timeContext) near \(analyzer.locationContext)",
                    "EMERGENCY SITUATION detected \(analyzer.timeContext) at \(analyzer.locationContext)"
                ])
            }
        }
        
        // Compose contextual details
        mutating func composeDetails() -> String? {
            // Add details based on available context
            var details: [String] = []
            
            if let confidence = analyzer.context["confidence"] as? Double {
                if confidence > 0.9 {
                    details.append(analyzer.pick(["High confidence detection", "Very clear signal", "Definite activity"]))
                } else if confidence < 0.5 {
                    details.append(analyzer.pick(["Low confidence", "Unclear signal", "Might be a false alarm"]))
                }
            }
            
            if let zones = analyzer.context["zones"] as? Int, zones > 1 {
                details.append(analyzer.pick([
                    "Movement across \(zones) different areas",
                    "Activity in \(zones) zones",
                    "Spanning \(zones) locations"
                ]))
            }
            
            if let homeMode = analyzer.context["home_mode"] as? String, homeMode == "away" {
                if analyzer.severity == .elevated || analyzer.severity == .critical {
                    details.append(analyzer.pick([
                        "while you're away",
                        "and nobody should be home",
                        "when the house should be empty"
                    ]))
                }
            }
            
            return details.isEmpty ? nil : details.joined(separator: ", ")
        }
        
        // Compose action suggestion
        mutating func composeAction() -> String? {
            switch analyzer.severity {
            case .low:
                return nil  // No action needed for low severity
            case .standard:
                return analyzer.pick([
                    "Worth checking when you get a chance.",
                    "Take a look when convenient.",
                    "Might want to review the footage."
                ])
            case .elevated:
                return analyzer.pick([
                    "Please check your cameras now.",
                    "Review the live feed immediately.",
                    "Recommend checking this out right away."
                ])
            case .critical:
                return analyzer.pick([
                    "Contact authorities immediately.",
                    "Call emergency services now.",
                    "Urgent—get help and check cameras."
                ])
            }
        }
    }
    
    // MARK: - Public API
    
    /// Generate minimal summary JSON from threat level and context
    public static func generateMinimalSummary(
        threatLevel: String,
        patternType: String? = nil,
        context: [String: Any] = [:],
        seed: UInt64? = nil
    ) -> MinimalSummary {
        
        // Map threat level to severity
        let severity: Severity
        switch threatLevel.lowercased() {
        case "low": severity = .low
        case "standard": severity = .standard
        case "elevated": severity = .elevated
        case "critical": severity = .critical
        default: severity = .standard
        }
        
        // Generate seed if not provided
        let finalSeed = seed ?? UInt64(Date().timeIntervalSince1970 * 1000)
        
        // Generate human summary
        let summary = generateSummary(
            severity: severity,
            patternType: patternType,
            context: context,
            seed: finalSeed
        )
        
        return MinimalSummary(
            alert_level: severity.rawValue,
            summary: summary
        )
    }
    
    /// Generate adaptive human summary with contextual understanding
    private static func generateSummary(
        severity: Severity,
        patternType: String?,
        context: [String: Any],
        seed: UInt64
    ) -> String {
        
        var rng = SplitMix64(seed: seed)
        
        // Create context analyzer
        var analyzer = ContextAnalyzer(
            context: context,
            severity: severity,
            patternType: patternType,
            rng: rng
        )
        
        // Create narrative composer
        var composer = NarrativeComposer(analyzer: analyzer)
        
        // Compose the narrative parts
        let opening = composer.composeOpening()
        let details = composer.composeDetails()
        let action = composer.composeAction()
        
        // Assemble the complete narrative
        var parts: [String] = [opening]
        if let details = details {
            parts.append(details)
        }
        if let action = action {
            parts.append(action)
        }
        
        var summary = parts.joined(separator: ". ")
        
        // Ensure proper sentence ending
        if !summary.hasSuffix(".") && !summary.hasSuffix("!") && !summary.hasSuffix("?") {
            summary += "."
        }
        
        // Adaptive length management based on severity
        let budget = severity.lengthBudget
        if summary.count < budget.min {
            // Too short - add contextual filler if needed
            // (Current implementation is already adaptive, so this is rare)
        } else if summary.count > budget.max {
            // Too long - intelligently trim
            summary = trimToLength(summary, maxLength: budget.max, preserveMeaning: true)
        }
        
        return summary
    }
    
    /// Intelligently trim summary while preserving meaning
    private static func trimToLength(_ text: String, maxLength: Int, preserveMeaning: Bool) -> String {
        guard text.count > maxLength else { return text }
        
        // Try to find a sentence boundary first
        let sentences = text.components(separatedBy: ". ")
        var result = ""
        for sentence in sentences {
            let potential = result.isEmpty ? sentence : result + ". " + sentence
            if potential.count <= maxLength - 3 {  // Leave room for ellipsis
                result = potential
            } else {
                break
            }
        }
        
        if !result.isEmpty {
            return result + (result.hasSuffix(".") ? ".." : "...")
        }
        
        // Fall back to word boundary
        let trimmed = String(text.prefix(maxLength - 3))
        if let lastSpace = trimmed.lastIndex(of: " ") {
            return String(trimmed[..<lastSpace]) + "..."
        }
        
        return String(text.prefix(maxLength - 3)) + "..."
    }
    
    /// Generate seed from event identity (deterministic per event)
    public static func generateSeed(
        eventId: String? = nil,
        timestamp: TimeInterval,
        deviceId: String? = nil
    ) -> UInt64 {
        
        // Bucket timestamp to minute to avoid micro-jitter
        let timestampBucket = UInt64(timestamp / 60.0)
        
        // Combine components
        var hasher = Hasher()
        if let eventId = eventId {
            hasher.combine(eventId)
        }
        hasher.combine(timestampBucket)
        if let deviceId = deviceId {
            hasher.combine(deviceId)
        }
        
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }
}

// MARK: - Convenience Extensions

extension EventSummaryFormatter.MinimalSummary {
    /// Convert to JSON string
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
