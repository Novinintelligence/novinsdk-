# NovinIntelligence™ SDK

**From Noise to Signal in Home Security.**

NovinIntelligence™ is an on-device AI SDK that ends alert fatigue by turning noisy, meaningless security notifications into clear, human-like intelligence. It filters out over 60% of false alarms and provides rich, actionable insights when a real threat is detected.

---

## Key Features

- **🧠 Human-Like Intelligence**: Understands the context behind events, distinguishing between a pet, a package delivery, and a prowler.
- **⚡️ Blazing Fast & On-Device**: All processing happens 100% on-device in under 30ms. No cloud costs, no latency.
- **🔒 Absolute Privacy**: Zero data leaves the user's device, providing a powerful privacy guarantee.
- **🗣️ Adaptive Summaries**: Delivers clear, narrative-based summaries instead of cryptic alerts.
- **Plug & Play**: Integrates seamlessly as a Swift Package.

## How to Integrate

Integrating the NovinIntelligence™ SDK is simple. Add it as a package dependency in Xcode.

1.  In Xcode, go to **File > Add Packages...**
2.  In the search bar, paste the repository URL:
    ```
    https://github.com/Novinintelligence/NovinIntelligence-.git
    ```
3.  Select the `NovinIntelligence` package and click **Add Package**.

### Example Usage

```swift
import NovinIntelligence

// Create your event context dictionary
let context: [String: Any] = [
    "timestamp": Date().timeIntervalSince1970,
    "location": "front_door",
    "type": "motion",
    "duration": 5.2
]

// Get the assessment
let assessment = NovinIntelligence.assess(context: context)

// Use the human-readable summary
print(assessment.summary)
// Output: "Brief motion was detected at the front door a few moments ago."
```

## Documentation

- **[QUICK_START.md](QUICK_START.md)**: A guide to getting started.
- **[COMPLETE_AI_BREAKDOWN.md](COMPLETE_AI_BREAKDOWN.md)**: A deep dive into the AI's architecture and capabilities.
- **[Patent Folder](patent/)**: Contains the provisional patent application drafts and technical drawings.

## License

This SDK is proprietary software. All rights are reserved.

Copyright (c) 2025 Oliver Herbert.

See the [LICENSE](LICENSE) file for more details. Usage of this software requires a separate written license agreement.
