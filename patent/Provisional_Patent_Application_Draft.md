# PROVISIONAL PATENT APPLICATION DRAFT

Title: On-Device Multi-Layer Security Intelligence with Adaptive Human Explanations

Applicant: [Assignee or Individual Name]
Inventors: [Full Legal Name(s)]
Filing Type: US Provisional Application (35 U.S.C. §111(b))

## 1. Field of the Invention
This invention relates to computer-implemented security systems. More particularly, it concerns on-device multi-layer artificial intelligence for analyzing smart-home or IoT sensor events to assess threat levels and generate human-understandable explanations with severity-adaptive tone, while operating securely and privately without cloud services.

## 2. Background
Conventional home security systems suffer from high false positive rates and generic alerts (e.g., "motion detected"). Cloud-dependent AI incurs latency, cost, and privacy risks. Existing systems often lack sequence awareness (event chains), spatial risk modeling (zones), probabilistic fusion, and human-level explanatory output. There is a need for an on-device, low-latency AI that understands the context behind events, reduces false positives, and communicates actionable explanations.

## 3. Summary
Disclosed is a hybrid, multi-layer AI that executes entirely on-device to process heterogeneous security events in ~15–30 ms with <10 MB runtime memory. The system maintains a sliding event window, detects real-world patterns (delivery, intrusion sequence, forced entry, glass break, prowler), classifies motion via hardware-accelerated vector math, scores spatial risk by zone and escalation, extracts features for rule reasoning, fuses evidence using Bayesian log-odds, dampens temporally, and emits a severity and an adaptive, human-readable explanation. Security hardening includes input validation, rate limiting, bounded buffers, thread safety, health monitoring, and graceful degradation modes.

## 4. Brief Description of the Drawings
- FIG. 1 is a system block diagram of the on-device AI pipeline.
- FIG. 2 is a process flow of the multi-layer inference pipeline.
- FIG. 3 illustrates event-chain pattern detection with a 60-second window.
- FIG. 4 depicts Bayesian fusion in log-odds space with weighted evidence factors.
- FIG. 5 shows the adaptive explanation engine components.

(See `patent/Drawings/*.mmd` Mermaid sources.)
 
Additional figures for summary generation and integration:
- FIG. 5A details the seeded variation mechanism (SplitMix64 PRNG flow and seed derivation buckets).
- FIG. 5B details the context analyzer (time, location, motion-quality extraction and option pickers).
- FIG. 5C details the severity-adaptive composition state machine (opening → details → action) and length control.
- FIG. 6 shows the minimal JSON contract (`alert_level`, `summary`) and SDK integration path to notifications/UI.

## 5. Detailed Description

### 5.1 Overall Architecture (FIG. 1)
A device executes a pipeline comprising: (i) Input Security Layer (validation, rate limiting); (ii) Event Chain Analyzer; (iii) Motion Analyzer (Accelerate/vDSP math); (iv) Zone Classifier (risk and escalation); (v) Feature Extraction & Rule Reasoning; (vi) Bayesian Fusion Engine; (vii) Temporal Dampening & Context; (viii) Adaptive Explanation Engine; (ix) Output & Audit Trail.

### 5.2 Event Chain Analyzer (FIG. 3)
Maintains a 60s sliding window of events and detects patterns:
- Package Delivery: Doorbell → Motion (2–30 s) → Silence ≥20 s → reduces threat.
- Intrusion Sequence: Motion → Door/Window → Continued Motion → increases threat.
- Forced Entry: ≥3 door/window events within ~15 s → increases threat.
- Active Break-In: Glass break → Motion (≤20 s) → increases threat (critical).
- Prowler: Motion across ≥3 distinct zones ≤60 s → increases threat.
Thread-safe buffer management avoids race conditions.

### 5.3 Motion Analyzer (Hardware-Accelerated)
Computes L2 norm, energy, and variance using Apple Accelerate (vDSP) for microsecond-level vector ops. Classifies activity into package drop, pet, loitering, walking, running, vehicle. These outputs feed rule reasoning and Bayesian fusion.

### 5.4 Zone Classifier (Spatial Intelligence)
Assigns base risk per zone (e.g., back door > front door > perimeter > interior) and detects escalation paths (perimeter→entry, entry→interior). Risk adjusts for home mode (home vs away) and time of day (night multiplier).

### 5.5 Feature Extraction & Rule Reasoning
Extracts >20 features (duration, energy, variance, zone transitions, door/window count, glass break presence, confidence). Decision trees generate intermediate threat signals and qualitative reasoning strings.

### 5.6 Bayesian Fusion (FIG. 4)
Combines evidence via log-odds addition with ~54 evidence factors (temporal, event, behavioral). Pet detection dampens; glass break strongly elevates. Fusion outputs a calibrated probability and level (low/standard/elevated/critical).

### 5.7 Temporal Dampening & Context
Applies time-of-day windows (delivery hours vs night), user pattern learning (delivery frequency, pet behavior), and mode awareness (home/away) to stabilize outputs and reduce false positives.

### 5.8 Adaptive Explanation Engine (FIG. 5)
The engine is implemented as a compositional narrative system that generates human-like summaries by analyzing time, location, motion quality, zone count, confidence, and home/away mode. Tone adapts to severity, and output length is enforced per severity.

Concretely, the implementation in `intelligence/EventSummaryFormatter.swift` comprises:

- Context understanding (`ContextAnalyzer`):
  - Extracts temporal phrases from `timestamp` by hour buckets, e.g., "in the dead of night", "this afternoon", via seeded variant selection.
  - Extracts location phrases from `location` (front/back/garage/window heuristics) and falls back to generic property phrases.
  - Derives motion-quality from `duration` thresholds: fleeting/brief/sustained/lengthy.
  - Provides a seeded `pick()` helper that selects among phrase options using a deterministic PRNG.

- Seeded PRNG (`SplitMix64`):
  - 64-bit state advanced with constants (0x9e3779b97f4a7c15, 0xbf58476d1ce4e5b9, 0x94d049bb133111eb) to yield statistically robust streams.
  - Supports `next()`, `nextDouble()`, and `choose(_:)` for weighted or uniform option selection.

- Severity model (`Severity` enum):
  - Levels: low, standard, elevated, critical.
  - Tone profiles: casual_reassuring, informative_neutral, concerned_actionable, urgent_directive.
  - Length budgets (min,max chars): low (40,85), standard (60,120), elevated (80,160), critical (90,200), enforced at the end of composition.

- Narrative composition (`NarrativeComposer`):
  - Opening selection varies by severity and pattern type (e.g., `delivery`, `pet`, `doorbell`, `motion`, `prowler`, `repeated_door`, `glass_break`, `interior_breach`, `forced_entry`).
  - Details incorporate contextual qualifiers when present: high/low `confidence`, multi-`zones`, and `home_mode == "away"` (only for elevated/critical).
  - Action suggestion depends on severity: none (low), optional check (standard), immediate review (elevated), contact authorities (critical).
  - Final assembly joins opening, details, and action with sentence-safe separators and then applies length control.

- Length control (`trimToLength`):
  - Prefers trimming at sentence boundaries; otherwise trims at a word boundary and appends an ellipsis to signal truncation.

Pattern detection for composition is supplied (in one embodiment) by a deterministic heuristic (`intelligence/EventSummaryIntegration.swift`, `detectPatternType(...)`) that maps input JSON to pattern types such as `glass_break`, `fire_smoke`, `interior_breach`, `forced_entry`, `repeated_door`, `prowler`, `pet`, `vehicle`, `delivery`, `doorbell`, or `motion`.

### 5.9 Security & Privacy Hardening
- Input validation: JSON size/depth/type limits.
- Rate limiting: token bucket (e.g., 100 req/s).
- Bounded buffers with automatic cleanup.
- Thread safety via serial queues.
- Health monitoring with auto mode fallback (full, degraded, minimal, emergency).
- 100% on-device processing; no PII stored; optional local-only telemetry.

### 5.10 Performance & Footprint
Typical end-to-end latency: 15–30 ms. Runtime memory <10 MB. SDK size <5 MB. Optimized via vectorized math and minimal allocations.

### 5.11 Example Embodiments
- On-device processing in mobile (iOS), hub, or edge device.
- Without cameras: sensor-only; or with cameras: fuses video-derived features.
- Rule weights configurable; evidence factors extendable; learning optional.

### 5.12 Best Mode
Use Accelerate/vDSP for vector ops, 60 s event buffer, the specified five chain patterns, zone risk table with escalation multipliers, ~54 evidence factors, and the compositional explanation engine.

### 5.13 Event Summary Formatter Implementation Details (Code-Backed)

This section ties the claimed engine to concrete API symbols for enablement:

- Public API: `EventSummaryFormatter.generateMinimalSummary(threatLevel:patternType:context:seed:) -> MinimalSummary`
  - Maps brand/SDK `threatLevel` strings to internal `Severity`.
  - Accepts optional `patternType` string from the pattern detector.
  - Accepts optional human/context map (e.g., `timestamp`, `location`, `duration`, `confidence`, `zones`, `home_mode`).
  - Uses a provided `seed` or generates one from time (ms) for default non-determinism.

- Deterministic seed: `EventSummaryFormatter.generateSeed(eventId:timestamp:deviceId:) -> UInt64`
  - Buckets `timestamp` to the minute to stabilize event clusters.
  - Hash-combines `eventId`, time-bucket, and `deviceId` via Swift `Hasher` to produce a 64-bit seed.
  - Guarantees: same identity → same seed; different identities/minutes → different seeds.

- Minimal JSON contract: `EventSummaryFormatter.MinimalSummary` with fields:
  - `alert_level`: "low" | "standard" | "elevated" | "critical" (derived from severity)
  - `summary`: human narrative, context-aware and length-controlled
  - Convenience: `toJSON()` pretty-prints a stable, sorted-keys JSON string.

- Integration example: `EventSummaryIntegration.generateSummaryFromAssessment(...)` shows how SDK output feeds the formatter, including pattern detection and deterministic seeding.

### 5.14 Minimal JSON Contract and End-to-End Flow (FIG. 6)

In one embodiment, the output contract is exactly:

```
{
  "alert_level": "low | standard | elevated | critical",
  "summary": "Human sentence, length-controlled by severity"
}
```

Brands may render this in notifications or UI, drive CTAs based on `alert_level`, and optionally log or A/B test variants.

### 5.15 Examples (Code-Backed)

- Example 1: After SDK assessment (see `intelligence/EventSummaryIntegration.swift`)

```swift
// Given an SDK result and original eventJson
let summary = try EventSummaryIntegration.generateSummaryFromAssessment(
    threatLevel: result.threatLevel.rawValue,
    eventJson: eventJson,
    eventId: "event-123",
    deviceId: "camera-1"
)
// Minimal JSON
let json = try summary.toJSON() // {"alert_level":"low","summary":"..."}
```

- Example 2: Direct generation with deterministic seed

```swift
let seed = EventSummaryFormatter.generateSeed(
    eventId: "event-456",
    timestamp: Date().timeIntervalSince1970,
    deviceId: "camera-2"
)
let summary = EventSummaryFormatter.generateMinimalSummary(
    threatLevel: "elevated",
    patternType: "prowler",
    seed: seed
)
```

- Example 3: Determinism and variation

```swift
let s1 = EventSummaryFormatter.generateMinimalSummary(threatLevel: "low", patternType: "delivery", seed: 1)
let s2 = EventSummaryFormatter.generateMinimalSummary(threatLevel: "low", patternType: "delivery", seed: 1) // same output
let s3 = EventSummaryFormatter.generateMinimalSummary(threatLevel: "low", patternType: "delivery", seed: 2) // variant
```


## 6. Optional Example Claims (Non-Limiting)
1. A computer-implemented method for on-device security threat assessment comprising: receiving sensor events; maintaining a sliding time window; detecting event-chain patterns; analyzing motion via hardware-accelerated vector operations; classifying zones and escalation; extracting features; computing threat probability by Bayesian fusion of evidence; applying temporal dampening and user context; generating an adaptive human-readable explanation; and outputting a threat level.
2. The method of claim 1 wherein the event-chain patterns comprise a package delivery sequence of doorbell followed by motion and subsequent silence.
3. The method of claim 1 wherein the motion analysis computes at least one of: L2 norm, energy, and variance using a vector processing framework.
4. The method of claim 1 wherein zone escalation from perimeter to entry increases a threat multiplier, and entry to interior triggers a breach condition.
5. The method of claim 1 wherein evidence factors comprise temporal, event, and behavioral factors including pet detection as a dampening factor and glass-break as a high-weight elevating factor.
6. The method of claim 1 further comprising rate limiting of assessment requests and bounded buffers for memory safety.
7. A non-transitory computer-readable medium storing instructions that when executed cause a device to perform the method of any of claims 1–6.
8. A system comprising a processor and memory configured to execute the method of any of claims 1–6.
9. The method of claim 1 further comprising generating a seeded pseudo-random variation of a natural-language explanation using a 64-bit SplitMix64 generator, wherein the seed is deterministically derived from an event identity comprising an event identifier, a timestamp bucketed to a minute, and an optional device identifier.
10. The method of claim 9 wherein identical event identities produce identical explanations and distinct event identities produce varied explanations across a finite set of phrasing options.
11. The method of claim 1 wherein the explanation tone and length are adapted to a severity level selected from low, standard, elevated, and critical, each with an associated character-length budget, and wherein text exceeding the budget is trimmed at sentence or word boundaries with an appended ellipsis.
12. The method of claim 1 further comprising selecting opening, detail, and action phrases based on detected pattern types comprising one or more of: delivery, pet, doorbell, motion, prowler, repeated door attempts, glass break, interior breach, and forced entry.
13. The system of claim 8 wherein the explanation engine exposes an API that returns a minimal JSON contract consisting essentially of an `alert_level` field and a `summary` field for consumption by downstream notification or UI systems.
14. The method of claim 9 wherein the seed generation hashes the event identity components using a platform-native hasher and integer-combines them to a 64-bit seed, with the timestamp normalized to a one-minute granularity to avoid micro-jitter within event clusters.
15. The method of claim 1 wherein, when no known pattern matches, a default narrative is produced using context-derived temporal and spatial phrases and severity-appropriate action guidance.

## 7. Advantages
Reduced false positives (60–70%), on-device privacy, low latency (<30 ms), explainable outputs, and graceful degradation.

## 8. Enablement & Support
Implementation details are provided in the accompanying materials (e.g., `SDK_AI_ANALYSIS.md`, `COMPLETE_AI_BREAKDOWN.md`, source code modules such as `EventSummaryFormatter.swift`), which illustrate how to realize each layer and ensure one of ordinary skill can practice the invention.

## 9. Incorporation by Reference
All documents in this repository related to the AI architecture and implementation are incorporated by reference to the extent permitted.

 
## 10. Filing Checklist and Timeline (Informative, Non-Limiting)

- Required documents for US provisional filing:
  - PTO/SB/16 (Provisional Cover Sheet) with applicant and inventor data.
  - Specification PDF (this document) and Drawings PDF (FIG. 1–6).
  - Filing fee (small/micro entity as applicable) via USPTO Patent Center.
- Optional attachments: data tables, appendix with extended test results.
- Patent Center eFiling steps:
  - Create new application → Provisional.
  - Upload spec/drawings as PDF(s) with textual OCR; upload cover sheet.
  - Pay fee; receive application number and filing receipt.
- Docketing and conversion:
  - Docket 12-month conversion deadline (non-extendable under 35 U.S.C. §119(e)).
  - Target: file non-provisional within 9–11 months claiming priority to this PPA.

## 11. Open Questions for Inventor (to Optimize Claim Coverage)

- Confirm severity length budgets for production: code currently enforces (min,max) as low (40,85), standard (60,120), elevated (80,160), critical (90,200). Any alternative ranges used in deployments?
- Confirm the definitive list of pattern types to enumerate in dependent claims (any additional patterns beyond those cited?).
- Any brand-specific style profiles or A/B testing hooks to claim as optional embodiments?
- Any hardware embodiments (edge hubs, doorbell SOCs) to include for system-level claims?

