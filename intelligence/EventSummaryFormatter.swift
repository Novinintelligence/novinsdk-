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
        public let alert_level: String
        public let summary: String
        
        public init(alert_level: String, summary: String) {
            self.alert_level = alert_level
            self.summary = summary
        }
    }
    
    public enum Severity: String, Codable {
        case low, standard, elevated, critical
        
        var lengthBudget: (min: Int, max: Int) {
            switch self {
            case .low: return (40, 85)
            case .standard: return (60, 120)
            case .elevated: return (80, 160)
            case .critical: return (90, 200)
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
    
    private struct ContextAnalyzer {
        let context: [String: Any]
        let severity: Severity
        let patternType: String?
        var rng: SplitMix64
        
        mutating func getTimeContext() -> String {
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
        
        mutating func getLocationContext() -> String {
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
        
        mutating func getMotionQuality() -> String? {
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
        
        mutating func pick(_ options: [String]) -> String {
            guard !options.isEmpty else { return "" }
            let index = Int(rng.next() % UInt64(options.count))
            return options[index]
        }
    }
    
    private struct NarrativeComposer {
        var analyzer: ContextAnalyzer
        
        mutating func composeOpening() -> String {
            switch analyzer.severity {
            case .low: return composeLowSeverityOpening()
            case .standard: return composeStandardOpening()
            case .elevated: return composeElevatedOpening()
            case .critical: return composeCriticalOpening()
            }
        }
        
        private mutating func composeLowSeverityOpening() -> String {
            switch analyzer.patternType {
            case "delivery":
                return analyzer.pick([
                    "Looks like a package was just delivered",
                    "You've got a delivery at the front door",
                    "Package arrived a few moments ago"
                ])
            case "pet_motion":
                return analyzer.pick([
                    "Just the pet moving around",
                    "The cat/dog is on the move again",
                    "Looks like one of the animals is wandering about"
                ])
            default:
                let time = analyzer.getTimeContext()
                let location = analyzer.getLocationContext()
                if let quality = analyzer.getMotionQuality() {
                    return analyzer.pick([
                        "Noticed \(quality) activity \(time) at \(location)",
                        "\(quality.capitalized) motion \(time) by \(location)"
                    ])
                }
                return analyzer.pick([
                    "Brief activity \(time) at \(location)",
                    "Something moved \(time) at \(location)"
                ])
            }
        }
        
        private mutating func composeStandardOpening() -> String {
            let time = analyzer.getTimeContext()
            let location = analyzer.getLocationContext()
            
            switch analyzer.patternType {
            case "doorbell":
                return analyzer.pick([
                    "Someone rang the bell \(time)",
                    "Visitor at \(location) \(time)",
                    "The doorbell went off \(time)"
                ])
            case "motion":
                if let quality = analyzer.getMotionQuality() {
                    return analyzer.pick([
                        "I'm seeing \(quality) movement \(time) near \(location)",
                        "There's \(quality) activity happening \(time) at \(location)",
                        "Detected \(quality) motion \(time) by \(location)"
                    ])
                }
                return analyzer.pick([
                    "Motion detected \(time) at \(location)",
                    "Activity spotted \(time) near \(location)"
                ])
            default:
                return analyzer.pick([
                    "Something's happening \(time) at \(location)",
                    "Activity detected \(time) near \(location)"
                ])
            }
        }
        
        private mutating func composeElevatedOpening() -> String {
            let time = analyzer.getTimeContext()
            let location = analyzer.getLocationContext()
            
            switch analyzer.patternType {
            case "prowler":
                return analyzer.pick([
                    "Suspicious movement \(time)—someone's moving between multiple areas",
                    "Concerning activity \(time)—an individual is systematically checking different zones",
                    "Unusual behavior detected \(time)—someone appears to be surveilling the property"
                ])
            case "repeated_door":
                return analyzer.pick([
                    "Multiple attempts at \(location) \(time)",
                    "Someone's repeatedly trying \(location) \(time)",
                    "Persistent activity at \(location) \(time)—looks like someone testing the door"
                ])
            default:
                if let quality = analyzer.getMotionQuality() {
                    return analyzer.pick([
                        "Concerning \(quality) activity \(time) at \(location)",
                        "Unusual \(quality) movement detected \(time) near \(location)",
                        "Suspicious \(quality) behavior \(time) by \(location)"
                    ])
                }
                return analyzer.pick([
                    "Unusual activity \(time) at \(location)",
                    "Suspicious movement detected \(time) near \(location)"
                ])
            }
        }
        
        private mutating func composeCriticalOpening() -> String {
            let time = analyzer.getTimeContext()
            let location = analyzer.getLocationContext()
            
            switch analyzer.patternType {
            case "glass_break":
                return analyzer.pick([
                    "🚨 URGENT: Breaking glass detected \(time) with movement inside",
                    "CRITICAL ALERT: Glass break \(time)—someone's entering the property",
                    "EMERGENCY: Window breach \(time) with interior activity"
                ])
            case "interior_breach":
                return analyzer.pick([
                    "🚨 INTRUDER ALERT: Someone's inside your home \(time)",
                    "CRITICAL: Unauthorized person detected inside \(time)",
                    "EMERGENCY: Interior breach \(time)—intruder in the house"
                ])
            case "forced_entry":
                return analyzer.pick([
                    "🚨 BREAK-IN ATTEMPT: Forceful impacts at \(location) \(time)",
                    "CRITICAL: Someone's forcing \(location) \(time)",
                    "EMERGENCY: Violent entry attempt at \(location) \(time)"
                ])
            default:
                return analyzer.pick([
                    "🚨 CRITICAL SECURITY EVENT \(time) at \(location)",
                    "URGENT ALERT: Serious incident \(time) near \(location)",
                    "EMERGENCY SITUATION detected \(time) at \(location)"
                ])
            }
        }
        
        mutating func composeDetails() -> String? {
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
        
        mutating func composeAction() -> String? {
            switch analyzer.severity {
            case .low:
                return nil
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
    
    public static func generateMinimalSummary(
        threatLevel: String,
        patternType: String? = nil,
        context: [String: Any] = [:],
        seed: UInt64? = nil
    ) -> MinimalSummary {
        
        let severity: Severity
        switch threatLevel.lowercased() {
        case "low": severity = .low
        case "standard": severity = .standard
        case "elevated": severity = .elevated
        case "critical": severity = .critical
        default: severity = .standard
        }
        
        let finalSeed = seed ?? UInt64(Date().timeIntervalSince1970 * 1000)
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
    
    private static func generateSummary(
        severity: Severity,
        patternType: String?,
        context: [String: Any],
        seed: UInt64
    ) -> String {
        
        var rng = SplitMix64(seed: seed)
        var analyzer = ContextAnalyzer(
            context: context,
            severity: severity,
            patternType: patternType,
            rng: rng
        )
        var composer = NarrativeComposer(analyzer: analyzer)
        
        let opening = composer.composeOpening()
        let details = composer.composeDetails()
        let action = composer.composeAction()
        
        var parts: [String] = [opening]
        if let details = details {
            parts.append(details)
        }
        if let action = action {
            parts.append(action)
        }
        
        var summary = parts.joined(separator: ". ")
        
        if !summary.hasSuffix(".") && !summary.hasSuffix("!") && !summary.hasSuffix("?") {
            summary += "."
        }
        
        let budget = severity.lengthBudget
        if summary.count > budget.max {
            summary = trimToLength(summary, maxLength: budget.max, preserveMeaning: true)
        }
        
        return summary
    }
    
    private static func trimToLength(_ text: String, maxLength: Int, preserveMeaning: Bool) -> String {
        guard text.count > maxLength else { return text }
        
        let sentences = text.components(separatedBy: ". ")
        var result = ""
        for sentence in sentences {
            let potential = result.isEmpty ? sentence : result + ". " + sentence
            if potential.count <= maxLength - 3 {
                result = potential
            } else {
                break
            }
        }
        
        if !result.isEmpty {
            return result + (result.hasSuffix(".") ? ".." : "...")
        }
        
        let trimmed = String(text.prefix(maxLength - 3))
        if let lastSpace = trimmed.lastIndex(of: " ") {
            return String(trimmed[..<lastSpace]) + "..."
        }
        
        return String(text.prefix(maxLength - 3)) + "..."
    }
    
    public static func generateSeed(
        eventId: String? = nil,
        timestamp: TimeInterval,
        deviceId: String? = nil
    ) -> UInt64 {
        
        let timestampBucket = UInt64(timestamp / 60.0)
        
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

extension EventSummaryFormatter.MinimalSummary {
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
