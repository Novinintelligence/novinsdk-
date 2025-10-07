import Foundation

@available(iOS 15.0, macOS 12.0, *)
struct FeatureExtractorSwift {
    struct Config {
        static let maxFeatures = 16_384
    }

    // MARK: - Constants & caches
    private static let hoursInDay = 24
    private static let daysInWeek = 7
    private static let monthsInYear = 12
    private static let hourSin: [Double] = (0..<hoursInDay).map { sin(2 * .pi * Double($0) / Double(hoursInDay)) }
    private static let hourCos: [Double] = (0..<hoursInDay).map { cos(2 * .pi * Double($0) / Double(hoursInDay)) }
    private static let weekdaySin: [Double] = (0..<daysInWeek).map { sin(2 * .pi * Double($0) / Double(daysInWeek)) }
    private static let weekdayCos: [Double] = (0..<daysInWeek).map { cos(2 * .pi * Double($0) / Double(daysInWeek)) }
    private static let monthSin: [Double] = (0..<monthsInYear).map { sin(2 * .pi * Double($0 + 1) / Double(monthsInYear)) }
    private static let monthCos: [Double] = (0..<monthsInYear).map { cos(2 * .pi * Double($0 + 1) / Double(monthsInYear)) }

    // Public API
    func extract(from request: [String: Any]) -> [Float] {
        var feats: [String: Double] = [:]

        // Temporal
        addTemporalFeatures(from: request, into: &feats)
        // Spatial
        addSpatialFeatures(from: request, into: &feats)
        // Event features (supports either top-level fields or first item under "events")
        let event = extractPrimaryEvent(from: request)
        addEventFeatures(from: event, into: &feats)
        // Behavioral
        addBehavioralFeatures(from: request, into: &feats)
        // Environmental
        addEnvironmentalFeatures(from: request, into: &feats)

        // Vectorize via MurmurHash3-32 slots
        var vector = [Float](repeating: 0, count: Config.maxFeatures)
        for (name, value) in feats {
            let slot = featureSlot(name)
            vector[slot] = Float(value)
        }
        return vector
    }

    /// New: Extract named features for math+rules pipeline
    func extractNamedFeatures(from request: [String: Any]) -> [String: Double] {
        var feats: [String: Double] = [:]
        // Temporal
        addTemporalFeatures(from: request, into: &feats)
        // Spatial
        addSpatialFeatures(from: request, into: &feats)
        // Event
        let event = extractPrimaryEvent(from: request)
        addEventFeatures(from: event, into: &feats)
        // Behavioral
        addBehavioralFeatures(from: request, into: &feats)
        // Environmental
        addEnvironmentalFeatures(from: request, into: &feats)
        return feats
    }

    // MARK: - Families
    private func addTemporalFeatures(from req: [String: Any], into out: inout [String: Double]) {
        let timestamp: TimeInterval = {
            if let t = req["timestamp"] as? TimeInterval { return t }
            if let s = req["timestamp"] as? String {
                let iso = ISO8601DateFormatter()
                if let d = iso.date(from: s) { return d.timeIntervalSince1970 }
            }
            return currentUnixTime()
        }()
        let date = Date(timeIntervalSince1970: timestamp)
        let cal = Calendar(identifier: .gregorian)
        let hour = cal.component(.hour, from: date)
        let weekday = cal.component(.weekday, from: date) - 1 // 0..6
        let month = cal.component(.month, from: date)

        out["hour_sin"] = Self.hourSin[hour]
        out["hour_cos"] = Self.hourCos[hour]
        let wd = max(0, min(Self.daysInWeek - 1, weekday))
        out["weekday_sin"] = Self.weekdaySin[wd]
        out["weekday_cos"] = Self.weekdayCos[wd]
        let mi = max(1, min(Self.monthsInYear, month)) - 1
        out["month_sin"] = Self.monthSin[mi]
        out["month_cos"] = Self.monthCos[mi]
        out["is_weekend"] = (weekday >= 5) ? 1.0 : 0.0

        if let lastT = req["last_event_time"] {
            let last: TimeInterval? = (lastT as? TimeInterval) ?? (lastT as? String).flatMap { ISO8601DateFormatter().date(from: $0)?.timeIntervalSince1970 }
            let deltaHrs = max(0, (timestamp - (last ?? timestamp)) / 3600.0)
            out["hours_since_last_event"] = min(deltaHrs, 24) / 24.0
        } else {
            out["hours_since_last_event"] = 1.0
        }
    }

    private func addSpatialFeatures(from req: [String: Any], into out: inout [String: Double]) {
        let loc = (req["location"] as? [String: Any]) ?? [:]
        let latRaw = (loc["latitude"] as? Double) ?? 0
        let lngRaw = (loc["longitude"] as? Double) ?? 0
        let lat = max(-90.0, min(90.0, latRaw))
        let lng = max(-180.0, min(180.0, lngRaw))

        let crime = (req["crime_context"] as? [String: Any]) ?? [:]

        out["latitude_norm"] = (lat + 90.0) / 180.0
        out["longitude_norm"] = (lng + 180.0) / 360.0
        out["crime_rate_24h"] = (crime["crime_rate_24h"] as? Double) ?? 0
        out["crime_rate_7d"] = (crime["crime_rate_7d"] as? Double) ?? 0
        out["crime_rate_30d"] = (crime["crime_rate_30d"] as? Double) ?? 0
        out["nearby_incidents"] = min(((crime["nearby_incidents"] as? Double) ?? 0), 20.0) / 20.0
        out["crime_severity"] = (crime["avg_severity"] as? Double) ?? 0
    }

    private func addEventFeatures(from event: [String: Any], into out: inout [String: Double]) {
        let rawType = ((event["type"] as? String) ?? (event["event_type"] as? String) ?? "unknown").lowercased()
        let type: String = {
            // Normalize common vendor-specific types
            if rawType.contains("motion") { return "motion" }
            if rawType.contains("glass") { return "glassbreak" }
            return rawType
        }()
        let data = (event["event_data"] as? [String: Any]) ?? (event["metadata"] as? [String: Any]) ?? [:]
        let eventTypes = ["motion","sound","door","window","face","smoke","fire","glassbreak","pet","vehicle"]
        for et in eventTypes {
            out["event_\(et)"] = (type == et) ? 1.0 : 0.0
        }
        // Derive specific subtypes
        if let soundType = (data["sound_type"] as? String)?.lowercased(), soundType.contains("glass") {
            out["event_glassbreak"] = 1.0
        }

        // Clamp numeric fields into [0,1] or normalized ranges
        let confidence = (data["confidence"] as? Double) ?? (event["confidence"] as? Double) ?? 0.5
        out["event_confidence"] = max(0.0, min(1.0, confidence))
        let duration = max(0.0, (data["duration"] as? Double) ?? 0)
        out["event_duration"] = min(duration, 600) / 600.0
        let intensity = (data["intensity"] as? Double) ?? 0.5
        out["event_intensity"] = max(0.0, min(1.0, intensity))
        if let sensors = data["sensors_triggered"] as? [Any] {
            out["sensor_count"] = min(Double(sensors.count), 6) / 6.0
        } else {
            out["sensor_count"] = 0.0
        }
    }

    private func addBehavioralFeatures(from req: [String: Any], into out: inout [String: Double]) {
        let hist = (req["activity_history"] as? [[String: Any]]) ?? []
        let tail = Array(hist.suffix(20))
        let risk = (req["user_risk_profile"] as? [String: Any]) ?? [:]

        out["recent_activity_freq"] = min(Double(tail.count), 20.0) / 20.0
        out["user_risk_score"] = (risk["risk_score"] as? Double) ?? 0.5
        out["user_trust_level"] = (risk["trust_level"] as? Double) ?? 0.5

        if !tail.isEmpty {
            let hours = tail.compactMap { $0["hour"] as? Double }
            if hours.count > 1 {
                let mean = hours.reduce(0, +) / Double(hours.count)
                // sample variance when n>1
                let variance = hours.reduce(0) { $0 + pow($1 - mean, 2) } / Double(hours.count - 1)
                let std = sqrt(max(0, variance))
                let score = 1.0 - (std / 12.0)
                out["activity_consistency"] = max(0.0, min(1.0, score))
            } else {
                out["activity_consistency"] = 0.5
            }
        } else {
            out["activity_consistency"] = 0.5
        }
    }

    private func addEnvironmentalFeatures(from req: [String: Any], into out: inout [String: Double]) {
        let weather = (req["weather"] as? [String: Any]) ?? [:]
        let timestamp = (req["timestamp"] as? TimeInterval) ?? currentUnixTime()
        let date = Date(timeIntervalSince1970: timestamp)
        let cal = Calendar(identifier: .gregorian)
        let hour = cal.component(.hour, from: date)
        let month = cal.component(.month, from: date)
        let seasonIndex = ((month % 12) / 3)

        out["temperature"] = (((weather["temperature"] as? Double) ?? 21) + 40.0) / 80.0
        out["humidity"] = ((weather["humidity"] as? Double) ?? 50) / 100.0
        out["precipitation"] = min(((weather["precipitation"] as? Double) ?? 0), 50.0) / 50.0
        out["wind_speed"] = min(((weather["wind_speed"] as? Double) ?? 0), 40.0) / 40.0
        out["is_daylight"] = ((6 <= hour && hour <= 18) ? 1.0 : 0.0)

        let seasons = ["season_winter", "season_spring", "season_summer", "season_fall"]
        for (idx, key) in seasons.enumerated() {
            out[key] = (idx == seasonIndex) ? 1.0 : 0.0
        }
    }

    // MARK: - Event selection
    private func extractPrimaryEvent(from req: [String: Any]) -> [String: Any] {
        if let events = req["events"] as? [[String: Any]], let first = events.first {
            return first
        }
        return req
    }

    // MARK: - Hashing & slots (stable across runs; Murmur3 x86_32, seed=0)
    private func featureSlot(_ name: String) -> Int {
        let h = murmurHash3_32(name)
        return Int(h % UInt32(Config.maxFeatures))
    }

    private func currentUnixTime() -> TimeInterval { Date().timeIntervalSince1970 }
}
 
// MARK: - Utilities
private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

// MARK: - MurmurHash3 (x86_32) with fixed seed for determinism
@available(iOS 15.0, macOS 12.0, *)
private func murmurHash3_32(_ s: String, seed: UInt32 = 0) -> UInt32 {
    let c1: UInt32 = 0xcc9e2d51
    let c2: UInt32 = 0x1b873593
    let r1: UInt32 = 15
    let r2: UInt32 = 13
    let m: UInt32 = 5
    let n: UInt32 = 0xe6546b64

    var hash = seed
    let data = Array(s.utf8)
    let len = data.count
    let nblocks = len / 4

    // body
    for i in 0..<nblocks {
        let i4 = i * 4
        var k: UInt32 = 0
        k |= UInt32(data[i4 + 0])
        k |= UInt32(data[i4 + 1]) << 8
        k |= UInt32(data[i4 + 2]) << 16
        k |= UInt32(data[i4 + 3]) << 24

        k &*= c1
        k = (k << r1) | (k >> (32 - r1))
        k &*= c2

        hash ^= k
        hash = ((hash << r2) | (hash >> (32 - r2)))
        hash = hash &* m &+ n
    }

    // tail
    var k1: UInt32 = 0
    let tailIndex = nblocks * 4
    let remaining = len & 3
    if remaining == 3 { k1 ^= UInt32(data[tailIndex + 2]) << 16 }
    if remaining >= 2 { k1 ^= UInt32(data[tailIndex + 1]) << 8 }
    if remaining >= 1 {
        k1 ^= UInt32(data[tailIndex + 0])
        k1 &*= c1
        k1 = (k1 << r1) | (k1 >> (32 - r1))
        k1 &*= c2
        hash ^= k1
    }

    // finalization
    hash ^= UInt32(len)

    // fmix
    hash ^= hash >> 16
    hash &*= 0x85ebca6b
    hash ^= hash >> 13
    hash &*= 0xc2b2ae35
    hash ^= hash >> 16

    return hash
}
