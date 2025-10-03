# Brand Integration Guide

**Step-by-step guide for integrating NovinIntelligence SDK**

---

## 📦 Installation

### Method 1: Swift Package Manager (Recommended)

**In Xcode:**
1. File → Add Package Dependencies
2. Enter local path: `/Users/Ollie/novin_intelligence-main`
3. Click "Add Package"
4. Select target and click "Add Package"

**In Package.swift:**
```swift
dependencies: [
    .package(path: "/Users/Ollie/novin_intelligence-main")
]
```

### Method 2: Framework

```bash
cd /Users/Ollie/novin_intelligence-main
swift build -c release
# Embed generated framework in Xcode project
```

---

## 🚀 Quick Integration (5 Minutes)

### Step 1: Import and Initialize

```swift
import NovinIntelligence

// In AppDelegate or App initialization
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize SDK (one-time)
        Task {
            try await NovinIntelligence.shared.initialize()
            print("✅ NovinIntelligence SDK ready")
        }
        
        return true
    }
}
```

### Step 2: Send Events

```swift
// When your sensor detects something:
func onMotionDetected(location: String, confidence: Double) async {
    
    // 1. Build JSON event
    let json = """
    {
        "type": "motion",
        "timestamp": \(Date().timeIntervalSince1970),
        "confidence": \(confidence),
        "metadata": {
            "location": "\(location)",
            "home_mode": "away"
        }
    }
    """
    
    // 2. Send to SDK
    do {
        let result = try await NovinIntelligence.shared.assess(requestJson: json)
        
        // 3. Use the result
        showAlert(
            title: result.summary ?? "Activity detected",
            message: result.detailedReasoning ?? "",
            action: result.recommendation ?? "Review footage",
            urgency: result.threatLevel
        )
        
    } catch {
        print("Error: \(error)")
    }
}
```

### Step 3: Display Results

```swift
func showAlert(title: String, message: String, action: String, urgency: ThreatLevel) {
    
    // Map threat level to notification style
    let notificationCategory: String
    let priority: UNNotificationPriority
    
    switch urgency {
    case .critical:
        notificationCategory = "CRITICAL_ALERT"
        priority = .high
    case .elevated:
        notificationCategory = "ELEVATED_ALERT"
        priority = .default
    case .standard, .low:
        notificationCategory = "INFO_ALERT"
        priority = .low
    }
    
    // Show notification
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    content.categoryIdentifier = notificationCategory
    content.interruptionLevel = (urgency == .critical) ? .critical : .active
    
    // Add action button from recommendation
    content.userInfo = ["action": action]
    
    // Send
    UNUserNotificationCenter.current().add(UNNotificationRequest(...))
}
```

---

## 📋 Event Types & Examples

### Motion Event
```json
{
    "type": "motion",
    "timestamp": 1727692800.0,
    "confidence": 0.9,
    "metadata": {
        "location": "front_door",
        "home_mode": "away",
        "duration": 5.0,
        "energy": 0.25
    }
}
```

### Doorbell Event
```json
{
    "type": "doorbell_chime",
    "timestamp": 1727692800.0,
    "confidence": 0.95,
    "metadata": {
        "location": "front_door",
        "home_mode": "home"
    }
}
```

### Door/Window Event
```json
{
    "type": "door",
    "timestamp": 1727692800.0,
    "confidence": 0.9,
    "metadata": {
        "location": "back_door",
        "motion_type": "opening",
        "home_mode": "away"
    }
}
```

### Glass Break Event
```json
{
    "type": "glass_break",
    "timestamp": 1727692800.0,
    "confidence": 0.95,
    "metadata": {
        "location": "living_room_window",
        "home_mode": "away"
    }
}
```

### Pet Detection
```json
{
    "type": "pet",
    "timestamp": 1727692800.0,
    "confidence": 0.82,
    "metadata": {
        "location": "hallway",
        "home_mode": "home"
    }
}
```

### Event Chain (Multiple Events)
```json
{
    "type": "doorbell_chime",
    "timestamp": 1727692800.0,
    "confidence": 0.9,
    "metadata": {
        "location": "front_door",
        "home_mode": "away"
    },
    "events": [
        {"type": "doorbell_chime", "timestamp": 1727692800.0},
        {"type": "motion", "timestamp": 1727692803.0}
    ]
}
```

---

## 🎨 Output Fields & Usage

### SecurityAssessment Object

```swift
struct SecurityAssessment {
    let threatLevel: ThreatLevel        
    let confidence: Double              
    let processingTimeMs: Double        
    let summary: String?                
    let detailedReasoning: String?      
    let context: [String]?              
    let recommendation: String?         
    let requestId: String?              
    let timestamp: String?              
}
```

### Usage Examples

**1. Notification Title:**
```swift
let title = result.summary ?? "Activity detected"
// "📦 Package delivery at front door"
```

**2. Notification Body:**
```swift
let body = result.detailedReasoning ?? "Unknown activity"
// "I detected a doorbell ring followed by brief motion..."
```

**3. Action Button:**
```swift
let actionText = result.recommendation ?? "Review footage"
// "Check for packages when you return home"
```

**4. Urgency Level:**
```swift
let isUrgent = (result.threatLevel == .critical || result.threatLevel == .elevated)
```

**5. Context Display:**
```swift
if let context = result.context {
    for factor in context {
        print("• \(factor)")
    }
}
// • Event sequence: package_delivery
// • Motion type: package_drop
// • Duration: 5s
```

---

## ⚙️ Configuration

### Temporal Settings

```swift
// Preset configurations
try NovinIntelligence.shared.configure(temporal: .default)      // Balanced
try NovinIntelligence.shared.configure(temporal: .aggressive)   // More alerts (Ring-like)
try NovinIntelligence.shared.configure(temporal: .conservative) // Fewer false positives

// Custom configuration
var config = TemporalConfiguration.default
config.daytimeDampeningFactor = 0.5    // 50% dampening during day
config.nightVigilanceBoost = 1.4        // 40% boost at night
config.deliveryWindowStart = 9          // 9 AM
config.deliveryWindowEnd = 18           // 6 PM
config.timezone = TimeZone.current
try NovinIntelligence.shared.configure(temporal: config)
```

### User Feedback (Learning)

```swift
// When user marks alert as false positive
NovinIntelligence.shared.provideFeedback(
    eventType: "doorbell_motion",
    wasFalsePositive: true
)

// SDK learns and adapts future assessments
```

---

## 🔍 Monitoring & Debugging

### System Health

```swift
let health = NovinIntelligence.shared.getSystemHealth()

print("Status: \(health.status)")                    // healthy, degraded, critical
print("Total Assessments: \(health.totalAssessments)")
print("Error Count: \(health.errorCount)")
print("Avg Processing: \(health.averageProcessingTimeMs)ms")
print("Rate Limit: \(health.rateLimit.utilizationPercent)%")
```

### Audit Trail

```swift
// Get specific audit trail
if let trail = NovinIntelligence.shared.getAuditTrail(requestId: uuid) {
    print("Input Hash: \(trail.inputHash)")
    print("Rules Triggered: \(trail.rulesTriggered)")
    print("Chain Pattern: \(trail.chainPattern ?? "none")")
}

// Get recent trails
let trails = NovinIntelligence.shared.getRecentAuditTrails(limit: 100)

// Export for compliance
if let json = NovinIntelligence.shared.exportAuditTrails() {
    // Save to file or send to server
}
```

### Telemetry

```swift
let metrics = NovinIntelligence.shared.getTelemetryMetrics()
print("Total Events: \(metrics.totalEvents)")
print("Dampened: \(metrics.dampenedEvents)")
print("Boosted: \(metrics.boostedEvents)")

// Export as JSON
if let json = NovinIntelligence.shared.exportTelemetry() {
    // Analyze dampening effectiveness
}
```

---

## 🎯 Brand-Specific Examples

### Ring Integration

```swift
class RingSecurityManager {
    private let ai = NovinIntelligence.shared
    
    init() {
        Task {
            // Use aggressive mode (Ring-like alerts)
            try await ai.initialize()
            try ai.configure(temporal: .aggressive)
        }
    }
    
    func handleEvent(_ event: RingEvent) async {
        let json = """
        {
            "type": "\(event.type)",
            "timestamp": \(event.timestamp),
            "confidence": \(event.confidence),
            "metadata": {
                "location": "\(event.location)",
                "home_mode": "\(getUserHomeMode())",
                "sensor_id": "\(event.sensorId)"
            }
        }
        """
        
        let result = try await ai.assess(requestJson: json)
        
        // Ring's notification style
        sendRingNotification(
            title: result.summary ?? "Activity detected",
            body: result.detailedReasoning ?? "",
            category: ringCategoryFor(result.threatLevel),
            action: result.recommendation ?? "Open Ring app"
        )
    }
}
```

### Nest Integration

```swift
class NestSecurityManager {
    private let ai = NovinIntelligence.shared
    
    init() {
        Task {
            // Use default balanced mode
            try await ai.initialize()
        }
    }
    
    func onCameraEvent(_ event: NestCameraEvent) async {
        // Use convenience method
        let result = try await ai.assessMotion(
            confidence: event.confidence,
            location: event.zone
        )
        
        // Nest's smart home integration
        updateNestApp(
            alert: result.summary ?? "Person detected",
            details: result.detailedReasoning ?? "",
            suggestedAction: result.recommendation ?? "View camera"
        )
    }
}
```

### SimpliSafe Integration

```swift
class SimpliSafeManager {
    private let ai = NovinIntelligence.shared
    
    func handleSensorTrigger(_ sensor: Sensor) async {
        let json = """
        {
            "type": "\(sensor.type)",
            "timestamp": \(Date().timeIntervalSince1970),
            "confidence": 0.95,
            "metadata": {
                "location": "\(sensor.location)",
                "home_mode": "\(getSystemMode())"
            }
        }
        """
        
        let result = try await ai.assess(requestJson: json)
        
        // SimpliSafe's monitoring integration
        if result.threatLevel == .critical {
            // Auto-dispatch if critical
            notifyMonitoringCenter(result)
        }
        
        sendUserAlert(result)
    }
}
```

---

## 🧪 Testing Your Integration

### Test Events

```swift
func testPackageDelivery() async {
    let json = """
    {
        "type": "doorbell_chime",
        "timestamp": \(Date().timeIntervalSince1970),
        "metadata": {"location": "front_door", "home_mode": "away"}
    }
    """
    
    let result = try await NovinIntelligence.shared.assess(requestJson: json)
    
    XCTAssertEqual(result.threatLevel, .low)
    XCTAssertTrue(result.summary?.contains("package") ?? false)
}

func testNightIntruder() async {
    let json = """
    {
        "type": "motion",
        "timestamp": \(Date().timeIntervalSince1970),
        "metadata": {"location": "backyard", "home_mode": "away"}
    }
    """
    
    let result = try await NovinIntelligence.shared.assess(requestJson: json)
    
    XCTAssertTrue([.elevated, .critical].contains(result.threatLevel))
}
```

---

## ❗ Error Handling

```swift
do {
    let result = try await NovinIntelligence.shared.assess(requestJson: json)
    // Process result
    
} catch let error as InputValidator.ValidationError {
    // Handle validation errors
    switch error {
    case .inputTooLarge(let size):
        print("Input too large: \(size) bytes")
    case .rateLimitExceeded:
        print("Rate limit exceeded, slow down")
    case .invalidJsonStructure:
        print("Invalid JSON format")
    default:
        print("Validation error: \(error)")
    }
    
} catch {
    // Handle other errors
    print("SDK error: \(error)")
}
```

---

## 🔧 Troubleshooting

**Q: SDK not initializing?**
```swift
// Check initialization status
Task {
    do {
        try await NovinIntelligence.shared.initialize()
        print("✅ Initialized")
    } catch {
        print("❌ Init failed: \(error)")
    }
}
```

**Q: Getting rate limited?**
```swift
// Check rate limit usage
let health = NovinIntelligence.shared.getSystemHealth()
print("Rate limit: \(health.rateLimit.utilizationPercent)%")

// Reset if needed (testing only)
NovinIntelligence.shared.resetRateLimiter()
```

**Q: Unexpected threat levels?**
```swift
// Check configuration
let config = NovinIntelligence.shared.getTemporalConfiguration()
print("Daytime dampening: \(config.daytimeDampeningFactor)")
print("Night boost: \(config.nightVigilanceBoost)")

// Adjust if needed
try NovinIntelligence.shared.configure(temporal: .conservative)
```

---

## 📊 Performance Tips

1. **Batch Similar Events**: Don't send 100 motion events/second
   ```swift
   // Debounce rapid events
   let debounced = event.debounce(for: 0.5)  // 500ms
   ```

2. **Use Async/Await**: Don't block main thread
   ```swift
   Task {
       let result = try await sdk.assess(requestJson: json)
       await MainActor.run {
           updateUI(result)
       }
   }
   ```

3. **Cache Configuration**: Don't reconfigure on every event
   ```swift
   // Configure once at startup
   try await sdk.initialize()
   try sdk.configure(temporal: .default)
   ```

---

## ✅ Integration Checklist

- [ ] SDK installed via Swift Package Manager
- [ ] SDK initialized in app startup
- [ ] Events formatted correctly (JSON)
- [ ] Results displayed to users (summary + recommendation)
- [ ] Threat levels mapped to UI urgency
- [ ] Error handling implemented
- [ ] Health monitoring set up (optional)
- [ ] User feedback collection (optional)
- [ ] Tested with real events
- [ ] Tested edge cases (rate limiting, errors)

---

## 📞 Support

Need help? Check:
- [README.md](README.md) - Full SDK documentation
- [API Reference](README.md#-api-reference) - Complete API docs
- [Examples](#-brand-specific-examples) - Brand integration examples

**Status**: Production ready, zero configuration needed. Just initialize and send events!



