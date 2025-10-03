import Foundation

/// Enterprise-grade input validation and security checks
@available(iOS 15.0, macOS 12.0, *)
public struct InputValidator {
    
    // MARK: - Security Limits
    private static let maxJsonSize: Int = 100_000  // 100KB - prevent DoS
    private static let maxEventsPerRequest: Int = 100
    private static let maxStringLength: Int = 10_000
    private static let minRequestInterval: TimeInterval = 0.01  // 100 req/sec max
    
    // MARK: - Validation Errors
    public enum ValidationError: Error, LocalizedError {
        case inputTooLarge(Int)
        case invalidJsonStructure
        case missingRequiredFields([String])
        case invalidFieldType(String, expected: String)
        case tooManyEvents(Int)
        case rateLimitExceeded
        case suspiciousInput(String)
        
        public var errorDescription: String? {
            switch self {
            case .inputTooLarge(let size):
                return "Input size \(size) bytes exceeds maximum \(maxJsonSize) bytes"
            case .invalidJsonStructure:
                return "Request is not valid JSON object"
            case .missingRequiredFields(let fields):
                return "Missing required fields: \(fields.joined(separator: ", "))"
            case .invalidFieldType(let field, let expected):
                return "Field '\(field)' has invalid type (expected: \(expected))"
            case .tooManyEvents(let count):
                return "Too many events (\(count)) exceeds maximum \(maxEventsPerRequest)"
            case .rateLimitExceeded:
                return "Rate limit exceeded - too many requests"
            case .suspiciousInput(let reason):
                return "Suspicious input detected: \(reason)"
            }
        }
    }
    
    // MARK: - Validation
    
    /// Validate JSON input size and structure
    public static func validateInput(_ requestJson: String) throws -> [String: Any] {
        // 1. Size check
        let byteCount = requestJson.utf8.count
        guard byteCount <= maxJsonSize else {
            throw ValidationError.inputTooLarge(byteCount)
        }
        
        // 2. Parse JSON
        guard let data = requestJson.data(using: .utf8),
              let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ValidationError.invalidJsonStructure
        }
        
        // 3. Basic structure validation
        try validateStructure(request)
        
        // 4. Security checks
        try performSecurityChecks(request)
        
        return request
    }
    
    /// Validate request structure
    private static func validateStructure(_ request: [String: Any]) throws {
        // Validate timestamp if present
        if let timestamp = request["timestamp"] {
            guard timestamp is Double || timestamp is Int else {
                throw ValidationError.invalidFieldType("timestamp", expected: "number")
            }
        }
        
        // Validate home_mode if present
        if let homeMode = request["home_mode"] as? String {
            let validModes = ["home", "away", "night", "vacation"]
            guard validModes.contains(homeMode) else {
                throw ValidationError.suspiciousInput("Invalid home_mode: \(homeMode)")
            }
        }
        
        // Validate events array if present
        if let events = request["events"] as? [[String: Any]] {
            guard events.count <= maxEventsPerRequest else {
                throw ValidationError.tooManyEvents(events.count)
            }
            
            for event in events {
                try validateEvent(event)
            }
        }
        
        // Validate metadata if present
        if let metadata = request["metadata"] as? [String: Any] {
            try validateMetadata(metadata)
        }
    }
    
    /// Validate individual event
    private static func validateEvent(_ event: [String: Any]) throws {
        // Type is optional, but if present must be string
        if let type = event["type"] {
            guard type is String else {
                throw ValidationError.invalidFieldType("event.type", expected: "string")
            }
            
            // Check for suspicious type strings
            if let typeStr = type as? String {
                guard typeStr.count <= 100 else {
                    throw ValidationError.suspiciousInput("Event type too long")
                }
            }
        }
        
        // Confidence must be 0-1 if present
        if let confidence = event["confidence"] as? Double {
            guard (0.0...1.0).contains(confidence) else {
                throw ValidationError.suspiciousInput("Confidence must be 0-1")
            }
        }
    }
    
    /// Validate metadata
    private static func validateMetadata(_ metadata: [String: Any]) throws {
        // Check for oversized strings
        for (key, value) in metadata {
            if let str = value as? String {
                guard str.count <= maxStringLength else {
                    throw ValidationError.suspiciousInput("Metadata '\(key)' exceeds max length")
                }
            }
        }
        
        // Validate location strings
        if let location = metadata["location"] as? String {
            guard location.count <= 200 else {
                throw ValidationError.suspiciousInput("Location string too long")
            }
        }
    }
    
    /// Security checks for malicious input
    private static func performSecurityChecks(_ request: [String: Any]) throws {
        // Check for deeply nested structures (potential stack overflow)
        let depth = calculateNestingDepth(request)
        guard depth <= 10 else {
            throw ValidationError.suspiciousInput("JSON nesting too deep")
        }
        
        // Check for excessively large arrays
        try validateArraySizes(request)
    }
    
    /// Calculate JSON nesting depth
    private static func calculateNestingDepth(_ obj: Any, currentDepth: Int = 0) -> Int {
        if let dict = obj as? [String: Any] {
            let maxChild = dict.values.map { calculateNestingDepth($0, currentDepth: currentDepth + 1) }.max() ?? currentDepth
            return maxChild
        } else if let arr = obj as? [Any] {
            let maxChild = arr.map { calculateNestingDepth($0, currentDepth: currentDepth + 1) }.max() ?? currentDepth
            return maxChild
        }
        return currentDepth
    }
    
    /// Validate array sizes
    private static func validateArraySizes(_ obj: Any) throws {
        if let dict = obj as? [String: Any] {
            for value in dict.values {
                try validateArraySizes(value)
            }
        } else if let arr = obj as? [Any] {
            guard arr.count <= 1000 else {
                throw ValidationError.suspiciousInput("Array too large")
            }
            for item in arr {
                try validateArraySizes(item)
            }
        }
    }
}




