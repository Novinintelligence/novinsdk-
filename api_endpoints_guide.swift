#!/usr/bin/env swift
import Foundation

print("""
================================================================================
📡 API ENDPOINTS - How Brands Push Events & Receive Output
================================================================================

MAIN ENTRY POINT FOR BRANDS:
""")

print("""
┌─────────────────────────────────────────────────────────────────┐
│ PRIMARY API: NovinIntelligence.shared.assess()                  │
│                                                                 │
│ Brands push JSON events → SDK returns SecurityAssessment       │
└─────────────────────────────────────────────────────────────────┘

PUBLIC API ENDPOINT:
  ✓ Function: assess(requestJson: String) async throws -> SecurityAssessment
  ✓ Input: JSON string with event data
  ✓ Output: SecurityAssessment object with full explanation
  ✓ Processing: Async/await (non-blocking)
  ✓ Thread-safe: Yes (internal queue)

================================================================================
📥 INPUT: How Brands Push Events
================================================================================

Brand sends JSON to this function:

  let result = try await NovinIntelligence.shared.assess(requestJson: json)
                          ↑                              ↑
                    SDK singleton                  JSON event data

JSON FORMAT (What brands send):
{
    "type": "motion" | "doorbell_chime" | "door" | "glass_break" | "pet",
    "timestamp": 1727692800.0,
    "confidence": 0.9,
    "metadata": {
        "location": "front_door",
        "home_mode": "away" | "home" | "night" | "vacation",
        "duration": 5.0,         // optional
        "energy": 0.25,          // optional
        "sensor_id": "sensor_1"  // optional
    },
    "events": [                   // optional - for event chains
        {"type": "doorbell_chime", "timestamp": 1727692800.0},
        {"type": "motion", "timestamp": 1727692803.0}
    ]
}

================================================================================
📤 OUTPUT: How SDK Returns Results
================================================================================

SDK returns SecurityAssessment object with ALL data:

struct SecurityAssessment {
    // CORE FIELDS
    let threatLevel: ThreatLevel           // .low, .standard, .elevated, .critical
    let confidence: Double                 // 0.0 to 1.0
    let processingTimeMs: Double           // How fast it was
    let reasoning: String                  // Technical reasoning
    let requestId: String?                 // UUID for tracking
    let timestamp: String?                 // ISO8601 timestamp
    
    // HUMAN-READABLE FIELDS (NEW!)
    let summary: String?                   // "📦 Package delivery at front door"
    let detailedReasoning: String?         // Full "why" explanation
    let context: [String]?                 // ["Event sequence: ...", "Time: ..."]
    let recommendation: String?            // "Check for packages when you return"
}

BRANDS ACCESS LIKE THIS:

  let result = try await sdk.assess(requestJson: json)
  
  // Use the fields:
  print(result.threatLevel)       // .low
  print(result.summary)            // "📦 Package delivery at front door"
  print(result.detailedReasoning)  // "I detected doorbell→motion→silence..."
  print(result.recommendation)     // "Check for packages when you return"
  print(result.processingTimeMs)   // 0.5

================================================================================
🔄 COMPLETE FLOW DIAGRAM
================================================================================

BRAND APP                    SDK ENTRY POINT              SDK PIPELINE
─────────                   ─────────────────            ─────────────

┌──────────┐                ┌─────────────┐             ┌──────────────┐
│  Motion  │                │             │             │   Validate   │
│ Detected │──── JSON ─────→│   assess()  │────────────→│    Input     │
└──────────┘                │             │             └──────────────┘
                            │  (PUBLIC)   │                     ↓
                            │             │             ┌──────────────┐
                            │             │             │  Rate Limit  │
                            │             │             │    Check     │
                            │             │             └──────────────┘
                            │             │                     ↓
                            │             │             ┌──────────────┐
                            │             │             │ Event Chain  │
                            │             │             │   Analysis   │
                            │             │             └──────────────┘
                            │             │                     ↓
                            │             │             ┌──────────────┐
                            │             │             │    Motion    │
                            │             │             │   Analysis   │
                            │             │             └──────────────┘
                            │             │                     ↓
                            │             │             ┌──────────────┐
                            │             │             │     Zone     │
                            │             │             │ Classification│
                            │             │             └──────────────┘
                            │             │                     ↓
                            │             │             ┌──────────────┐
                            │             │             │  AI Fusion   │
                            │             │             │  & Reasoning │
                            │             │             └──────────────┘
                            │             │                     ↓
                            │             │             ┌──────────────┐
                            │             │             │ Explanation  │
                            │             │             │   Engine     │
┌──────────┐                │             │             └──────────────┘
│  Show    │                │             │                     ↓
│  Alert   │←── Result ─────│             │←────────────────────┘
└──────────┘                └─────────────┘       SecurityAssessment

================================================================================
💡 ALTERNATIVE ENDPOINTS (For Different Use Cases)
================================================================================

1. PRIMARY (Most Common):
   assess(requestJson: String) -> SecurityAssessment
   ↑ Brands use this 99% of the time

2. PI-FORMAT (For Partner Integrations like locw.ly):
   assessPI(requestJson: String) -> String (JSON)
   ↑ Returns JSON in partner-integration format

3. SIMPLE HELPERS (Convenience):
   assessMotion(confidence: Double, location: String) -> SecurityAssessment
   assessDoorEvent(isOpening: Bool, location: String) -> SecurityAssessment
   ↑ Quick wrappers for common events

================================================================================
📋 REAL EXAMPLE: Ring Integration
================================================================================
""")

print("""
// RING'S CODE (in their iOS app):

import NovinIntelligence

class RingSecurityManager {
    let ai = NovinIntelligence.shared
    
    init() {
        Task {
            try await ai.initialize()  // One-time setup
        }
    }
    
    // When Ring detects motion:
    func onMotionDetected(location: String, confidence: Double) async {
        
        // 1. Build JSON event
        let json = \"\"\"
        {
            "type": "motion",
            "timestamp": \\(Date().timeIntervalSince1970),
            "confidence": \\(confidence),
            "metadata": {
                "location": "\\(location)",
                "home_mode": "away",
                "sensor_id": "ring_motion_123"
            }
        }
        \"\"\"
        
        // 2. Send to SDK (ENTRY POINT)
        do {
            let result = try await ai.assess(requestJson: json)
            
            // 3. Receive output (AUTOMATIC)
            print("Threat: \\(result.threatLevel)")           // .low
            print("Summary: \\(result.summary ?? "")")        // "📦 Package delivery"
            print("Action: \\(result.recommendation ?? "")")  // "Check for packages"
            
            // 4. Show to user
            showNotification(
                title: result.summary ?? "Activity detected",
                body: result.detailedReasoning ?? "",
                action: result.recommendation ?? "Review footage"
            )
            
        } catch {
            print("Error: \\(error)")
        }
    }
    
    func showNotification(title: String, body: String, action: String) {
        // Ring's notification system
        // Shows AI-generated explanation to user
    }
}

OUTPUT RING GETS:
{
    "threatLevel": "low",
    "confidence": 0.75,
    "processingTimeMs": 0.8,
    "summary": "📦 Likely a package delivery at your front door",
    "detailedReasoning": "I detected doorbell ring followed by brief motion...",
    "context": ["Event sequence: package_delivery", "Motion type: package_drop"],
    "recommendation": "📦 Likely a delivery. Check for packages when you return."
}

Ring shows this to user in their app!
================================================================================

📊 API SUMMARY TABLE
================================================================================

ENDPOINT                      INPUT              OUTPUT                    USE CASE
────────────────────────────────────────────────────────────────────────────────
assess(requestJson:)          JSON String        SecurityAssessment       PRIMARY
assessPI(requestJson:)        JSON String        JSON String              Partners
assessMotion(...)             Parameters         SecurityAssessment       Convenience
assessDoorEvent(...)          Parameters         SecurityAssessment       Convenience
configure(temporal:)          Config             Void                     Setup
provideFeedback(...)          Event+Bool         Void                     Learning
getSystemHealth()             -                  SystemHealth             Monitoring

================================================================================
🔐 THREAD SAFETY & ASYNC
================================================================================

✅ SDK is FULLY THREAD-SAFE:
  - All public APIs use internal DispatchQueue
  - Brands can call from any thread
  - Async/await pattern (non-blocking)
  - Multiple simultaneous requests handled correctly

✅ RATE LIMITING AUTOMATIC:
  - 100 requests/second max
  - TokenBucket algorithm
  - Brands don't need to throttle manually

✅ ERROR HANDLING:
  - Throws ValidationError for bad input
  - Never crashes
  - Always returns valid response (or throws)

================================================================================
📱 HOW BRANDS RECEIVE OUTPUT
================================================================================

METHOD 1: Direct Result Object (Recommended)
─────────────────────────────────────────────
let result = try await sdk.assess(requestJson: json)
// Access fields directly:
result.summary           // "📦 Package delivery"
result.recommendation    // "Check for packages"
result.threatLevel       // .low

METHOD 2: PI-Format JSON (For Integrations)
────────────────────────────────────────────
let jsonOutput = try await sdk.assessPI(requestJson: json)
// Returns JSON string:
{
  "event_type": "security_assessment",
  "threat": {"level": "low", "confidence_pct": 75},
  "meta": {
    "summary": "📦 Package delivery",
    "recommendation": "Check for packages"
  }
}

METHOD 3: Callback Pattern (If needed)
───────────────────────────────────────
Task {
    let result = try await sdk.assess(requestJson: json)
    DispatchQueue.main.async {
        self.updateUI(with: result)
    }
}

================================================================================
✅ FINAL ANSWER
================================================================================

WHERE DO BRANDS PUSH EVENTS?
  → NovinIntelligence.shared.assess(requestJson: String)
  → Single public async function
  → Thread-safe, rate-limited, validated

HOW DOES SDK SEND OUTPUT BACK?
  → Returns SecurityAssessment object
  → Contains: threatLevel, summary, reasoning, recommendation, context
  → Async/await pattern (non-blocking)
  → <1ms response time

INTEGRATION STEPS:
  1. Initialize: try await NovinIntelligence.shared.initialize()
  2. Send event: let result = try await sdk.assess(requestJson: json)
  3. Use output: display result.summary and result.recommendation

That's it! One entry point, automatic processing, rich output.
================================================================================
""")


