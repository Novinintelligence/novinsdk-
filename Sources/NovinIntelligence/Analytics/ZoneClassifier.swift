import Foundation

/// Enterprise zone classification with risk scoring
@available(iOS 15.0, macOS 12.0, *)
public struct ZoneClassifier {
    
    // MARK: - Types
    
    public struct Zone: Codable {
        public let name: String
        public let riskScore: Double        // 0-1, inherent risk of zone
        public let type: ZoneType
        public let aliases: [String]
        public let adjacentZones: [String]
        public let geofence: Geofence?
        
        public init(name: String, riskScore: Double, type: ZoneType, aliases: [String] = [], adjacentZones: [String] = [], geofence: Geofence? = nil) {
            self.name = name
            self.riskScore = riskScore
            self.type = type
            self.aliases = aliases
            self.adjacentZones = adjacentZones
            self.geofence = geofence
        }
    }
    
    public enum ZoneType: String, Codable {
        case entry          // Front door, back door
        case perimeter      // Backyard, side yard
        case interior       // Living room, bedroom
        case publicArea     // Street, sidewalk (renamed from 'public' - reserved keyword)
        case garage         // Garage, carport
        case restricted     // Safe room, storage
        case transition     // Hallway, stairs
        case outdoor        // Patio, deck
    }
    
    public struct Geofence: Codable {
        public let centerLat: Double
        public let centerLon: Double
        public let radiusMeters: Double
        
        public init(centerLat: Double, centerLon: Double, radiusMeters: Double) {
            self.centerLat = centerLat
            self.centerLon = centerLon
            self.radiusMeters = radiusMeters
        }
    }
    
    // MARK: - Default Zones
    
    /// Standard residential zone configuration
    public static let defaultZones: [Zone] = [
        // Entry points (highest risk)
        Zone(name: "front_door", riskScore: 0.7, type: .entry, aliases: ["front", "frontdoor", "main_entrance"]),
        Zone(name: "back_door", riskScore: 0.75, type: .entry, aliases: ["back", "backdoor", "rear_entrance"]),
        Zone(name: "side_door", riskScore: 0.72, type: .entry, aliases: ["side", "sidedoor"]),
        
        // Perimeter (high risk)
        Zone(name: "backyard", riskScore: 0.65, type: .perimeter, aliases: ["back_yard", "rear_yard", "garden"]),
        Zone(name: "side_yard", riskScore: 0.68, type: .perimeter, aliases: ["sideyard"]),
        Zone(name: "front_yard", riskScore: 0.50, type: .perimeter, aliases: ["frontyard", "lawn"]),
        
        // Garage (medium-high risk)
        Zone(name: "garage", riskScore: 0.62, type: .garage, aliases: ["carport", "parking"]),
        
        // Outdoor (medium risk)
        Zone(name: "porch", riskScore: 0.55, type: .outdoor, aliases: ["front_porch", "patio"]),
        Zone(name: "deck", riskScore: 0.58, type: .outdoor, aliases: ["back_porch", "balcony"]),
        Zone(name: "driveway", riskScore: 0.45, type: .outdoor, aliases: ["drive"]),
        
        // Public (lower risk)
        Zone(name: "street", riskScore: 0.30, type: .publicArea, aliases: ["road", "sidewalk"]),
        
        // Interior (lower risk when home)
        Zone(name: "living_room", riskScore: 0.35, type: .interior, aliases: ["livingroom", "lounge"]),
        Zone(name: "bedroom", riskScore: 0.40, type: .interior, aliases: ["master_bedroom", "guest_room"]),
        Zone(name: "kitchen", riskScore: 0.33, type: .interior, aliases: ["dining"]),
        Zone(name: "hallway", riskScore: 0.30, type: .transition, aliases: ["corridor"]),
        
        // Unknown fallback
        Zone(name: "unknown", riskScore: 0.50, type: .publicArea, aliases: [])
    ]
    
    // MARK: - Classification
    
    private let zones: [Zone]
    
    /// Initialize with custom zones
    public init(zones: [Zone] = defaultZones) {
        self.zones = zones
    }
    
    /// Classify a location string to a zone
    public func classifyLocation(_ location: String) -> Zone {
        let normalized = location.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct name match
        if let zone = zones.first(where: { $0.name == normalized }) {
            return zone
        }
        
        // Alias match
        if let zone = zones.first(where: { $0.aliases.contains(normalized) }) {
            return zone
        }
        
        // Partial match (e.g., "front_door_camera" → "front_door")
        if let zone = zones.first(where: { normalized.contains($0.name) }) {
            return zone
        }
        
        // Fallback to unknown
        return zones.first { $0.name == "unknown" } ?? Zone(name: "unknown", riskScore: 0.50, type: .publicArea)
    }
    
    /// Get risk score for location
    public func getRiskScore(for location: String) -> Double {
        return classifyLocation(location).riskScore
    }
    
    /// Get zone type for location
    public func getZoneType(for location: String) -> ZoneType {
        return classifyLocation(location).type
    }
    
    /// Check if location is high-risk entry point
    public func isEntryPoint(_ location: String) -> Bool {
        let zone = classifyLocation(location)
        return zone.type == .entry
    }
    
    /// Check if location is perimeter
    public func isPerimeter(_ location: String) -> Bool {
        let zone = classifyLocation(location)
        return zone.type == .perimeter || zone.type == .outdoor
    }
    
    /// Get adjacent zones
    public func getAdjacentZones(for location: String) -> [Zone] {
        let zone = classifyLocation(location)
        return zone.adjacentZones.compactMap { adjacentName in
            zones.first { $0.name == adjacentName }
        }
    }
    
    /// Calculate risk escalation based on zone sequence
    /// - Parameter locationSequence: Array of locations in chronological order
    /// - Returns: Escalation factor (1.0 = no escalation, >1.0 = escalated)
    public func calculateZoneEscalation(_ locationSequence: [String]) -> Double {
        guard locationSequence.count >= 2 else { return 1.0 }
        
        let zones = locationSequence.map { classifyLocation($0) }
        var escalation = 1.0
        
        // Pattern: Perimeter → Entry = High escalation (approaching)
        for i in 0..<(zones.count - 1) {
            let current = zones[i]
            let next = zones[i + 1]
            
            // Perimeter → Entry
            if current.type == .perimeter && next.type == .entry {
                escalation *= 1.8
            }
            
            // Entry → Interior (breach)
            if current.type == .entry && next.type == .interior {
                escalation *= 2.0
            }
            
            // Multiple perimeter zones (prowling)
            if current.type == .perimeter && next.type == .perimeter && current.name != next.name {
                escalation *= 1.4
            }
        }
        
        return min(3.0, escalation)  // Cap at 3x
    }
}
