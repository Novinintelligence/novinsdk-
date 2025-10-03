//
//  EventSummaryIntegration.swift
//  intelligence
//
//  Created on 02/10/2025.
//  Integration example: Using EventSummaryFormatter with NovinIntelligence SDK
//

import Foundation

/// Example integration showing how to generate human summaries from SDK results
public struct EventSummaryIntegration {
    
    // MARK: - Integration Example
    
    /// Generate minimal summary from SDK assessment result
    /// This is what brands would call after assess() to get human-readable output
    public static func generateSummaryFromAssessment(
        threatLevel: String,
        eventJson: String,
        eventId: String? = nil,
        deviceId: String? = nil
    ) throws -> EventSummaryFormatter.MinimalSummary {
        
        // Parse event JSON to extract context
        guard let data = eventJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "EventSummary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        
        // Extract timestamp
        let timestamp = json["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
        
        // Detect pattern type from events
        let patternType = detectPatternType(from: json, threatLevel: threatLevel)
        
        // Generate deterministic seed
        let seed = EventSummaryFormatter.generateSeed(
            eventId: eventId,
            timestamp: timestamp,
            deviceId: deviceId
        )
        
        // Generate summary
        return EventSummaryFormatter.generateMinimalSummary(
            threatLevel: threatLevel,
            patternType: patternType,
            context: json,
            seed: seed
        )
    }
    
    // MARK: - Pattern Detection
    
    /// Detect pattern type from event JSON for better summary selection
    private static func detectPatternType(from json: [String: Any], threatLevel: String) -> String? {
        
        guard let events = json["events"] as? [[String: Any]] else {
            return nil
        }
        
        let eventTypes = events.compactMap { $0["type"] as? String }
        let homeMode = json["home_mode"] as? String ?? "away"
        let location = (json["metadata"] as? [String: Any])?["location"] as? String
        
        // Critical patterns
        if eventTypes.contains("glassbreak") {
            return "glass_break"
        }
        
        if eventTypes.contains("smoke") || eventTypes.contains("fire") {
            return "fire_smoke"
        }
        
        // Interior breach while away
        if homeMode == "away" && location != nil && ["living_room", "bedroom", "kitchen"].contains(location!) {
            return "interior_breach"
        }
        
        // Forced entry (multiple door events)
        let doorCount = eventTypes.filter { $0 == "door" }.count
        if doorCount >= 3 {
            return "forced_entry"
        }
        
        // Elevated patterns
        if doorCount >= 2 {
            return "repeated_door"
        }
        
        // Prowler (multiple zones or motion events)
        let motionCount = eventTypes.filter { $0 == "motion" }.count
        if motionCount >= 3 {
            return "prowler"
        }
        
        // Low severity patterns
        if eventTypes.contains("pet") {
            return "pet"
        }
        
        if eventTypes.contains("vehicle") {
            return "vehicle"
        }
        
        // Delivery pattern (doorbell + brief motion)
        if eventTypes.contains("doorbell_chime") && eventTypes.contains("motion") {
            // Check if motion is brief
            if let motionEvent = events.first(where: { $0["type"] as? String == "motion" }),
               let metadata = motionEvent["metadata"] as? [String: Any],
               let duration = metadata["duration"] as? Double,
               duration < 15 {
                return "delivery"
            }
        }
        
        // Standard patterns
        if eventTypes.contains("doorbell_chime") {
            return "doorbell"
        }
        
        if eventTypes.contains("motion") {
            return "motion"
        }
        
        return nil
    }
}

// MARK: - Usage Examples

/*
 
 EXAMPLE 1: Basic Usage After SDK Assessment
 ────────────────────────────────────────────
 
 let eventJson = """
 {
     "timestamp": \(Date().timeIntervalSince1970),
     "home_mode": "away",
     "events": [
         {"type": "doorbell_chime", "confidence": 0.95},
         {"type": "motion", "confidence": 0.88, "metadata": {"duration": 8}}
     ],
     "metadata": {"location": "front_door"}
 }
 """
 
 // Call SDK
 let result = try await NovinIntelligence.shared.assess(requestJson: eventJson)
 
 // Generate human summary
 let summary = try EventSummaryIntegration.generateSummaryFromAssessment(
     threatLevel: result.threatLevel.rawValue,
     eventJson: eventJson,
     eventId: "event-123",
     deviceId: "camera-1"
 )
 
 print(summary.alert_level)  // "low"
 print(summary.summary)      // "Looks like a delivery—quick drop‑off at the front door."
 
 // Send to notification system
 let json = try summary.toJSON()
 sendPushNotification(json)
 
 
 EXAMPLE 2: Direct Minimal Summary Generation
 ─────────────────────────────────────────────
 
 let summary = EventSummaryFormatter.generateMinimalSummary(
     threatLevel: "elevated",
     patternType: "prowler",
     seed: EventSummaryFormatter.generateSeed(
         eventId: "event-456",
         timestamp: Date().timeIntervalSince1970,
         deviceId: "camera-2"
     )
 )
 
 print(summary.alert_level)  // "elevated"
 print(summary.summary)      // "Movement across multiple zones at night—please check live view."
 
 
 EXAMPLE 3: Batch Processing with Consistent Seeds
 ──────────────────────────────────────────────────
 
 let events = [
     ("event-1", "low", "delivery"),
     ("event-2", "elevated", "prowler"),
     ("event-3", "critical", "glass_break")
 ]
 
 for (eventId, level, pattern) in events {
     let seed = EventSummaryFormatter.generateSeed(
         eventId: eventId,
         timestamp: Date().timeIntervalSince1970,
         deviceId: "camera-1"
     )
     
     let summary = EventSummaryFormatter.generateMinimalSummary(
         threatLevel: level,
         patternType: pattern,
         seed: seed
     )
     
     print("\(eventId): \(summary.summary)")
 }
 
 
 EXAMPLE 4: JSON API Response
 ─────────────────────────────
 
 // In your API endpoint
 func handleSecurityEvent(request: EventRequest) async throws -> Response {
     
     // Call SDK
     let result = try await NovinIntelligence.shared.assess(requestJson: request.eventJson)
     
     // Generate summary
     let summary = try EventSummaryIntegration.generateSummaryFromAssessment(
         threatLevel: result.threatLevel.rawValue,
         eventJson: request.eventJson,
         eventId: request.eventId,
         deviceId: request.deviceId
     )
     
     // Return minimal JSON
     return Response(
         statusCode: 200,
         body: try summary.toJSON()
     )
 }
 
 // Client receives:
 {
   "alert_level": "elevated",
   "summary": "Movement across multiple zones at night—please check live view."
 }
 
 
 EXAMPLE 5: UI Integration
 ──────────────────────────
 
 struct SecurityAlertView: View {
     let summary: EventSummaryFormatter.MinimalSummary
     
     var body: some View {
         VStack(alignment: .leading, spacing: 12) {
             // Severity indicator
             HStack {
                 severityIcon
                 Text(summary.alert_level.uppercased())
                     .font(.caption)
                     .fontWeight(.semibold)
             }
             
             // Human summary
             Text(summary.summary)
                 .font(.body)
             
             // Action buttons based on severity
             actionButtons
         }
         .padding()
         .background(severityColor.opacity(0.1))
         .cornerRadius(12)
     }
     
     var severityIcon: some View {
         switch summary.alert_level {
         case "low": return Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
         case "standard": return Image(systemName: "info.circle.fill").foregroundColor(.blue)
         case "elevated": return Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
         case "critical": return Image(systemName: "exclamationmark.octagon.fill").foregroundColor(.red)
         default: return Image(systemName: "circle.fill").foregroundColor(.gray)
         }
     }
     
     var actionButtons: some View {
         HStack {
             if summary.alert_level == "critical" {
                 Button("Live View") { /* ... */ }
                 Button("Call") { /* ... */ }
             } else if summary.alert_level == "elevated" {
                 Button("Live View") { /* ... */ }
                 Button("Lights On") { /* ... */ }
             } else {
                 Button("Open Clip") { /* ... */ }
             }
         }
     }
 }
 
 */
