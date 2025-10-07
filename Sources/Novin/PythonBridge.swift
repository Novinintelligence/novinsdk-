import Foundation

/// Swift-only stub preserved for API compatibility in Swift-only builds
public class PythonBridge {
    public static let shared = PythonBridge()
    private var isInitialized = false
    private init() {}

    public func initialize() throws {
        // No-op in Swift-only build
        isInitialized = true
    }

    public func processRequest(_ requestJson: String, clientId: String = "ios_client") -> Result<String, NovinIntelligenceError> {
        // Not used in Swift-only build; return error if called
        return .failure(.processingFailed("Python bridge is disabled in Swift-only build"))
    }
}
