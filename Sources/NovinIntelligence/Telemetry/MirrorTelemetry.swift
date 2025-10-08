import Foundation

/// Lightweight telemetry for Environmental Mirror (training-free, on-device)
public final class MirrorTelemetry {
    public static let shared = MirrorTelemetry()
    private init() {}

    private let queue = DispatchQueue(label: "com.novinintelligence.mirrortelemetry")

    // Last-recorded values (for audit wiring)
    public private(set) var lastMissing: Int = 0
    public private(set) var lastUnexpected: Int = 0
    public private(set) var lastUpdates: Int = 0

    // Aggregates (not currently exposed via public API)
    private var totalEvents: Int = 0
    private var totalMatches: Int = 0
    private var totalMismatches: Int = 0
    private var totalUpdates: Int = 0
    private var totalDurationMs: Double = 0

    public func record(missing: Int, unexpected: Int, updates: Int, durationMs: Double) {
        queue.sync {
            self.lastMissing = missing
            self.lastUnexpected = unexpected
            self.lastUpdates = updates

            self.totalEvents += 1
            if missing == 0 && unexpected == 0 { self.totalMatches += 1 } else { self.totalMismatches += 1 }
            self.totalUpdates += updates
            self.totalDurationMs += max(0, durationMs)
        }
    }
}
