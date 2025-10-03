import XCTest
@testable import NovinIntelligence

/// Motion analysis tests (P1.2 feature)
@available(iOS 15.0, macOS 12.0, *)
final class MotionAnalysisTests: XCTestCase {
    
    // MARK: - Package Drop Detection
    
    func testPackageDropMotion() {
        // Brief, low energy motion
        let rawData = [0.2, 0.3, 0.4, 0.3, 0.2, 0.1]
        let features = MotionAnalyzer.analyzeMotionVector(
            rawData,
            sampleRate: 10.0,
            duration: 5.0
        )
        
        XCTAssertEqual(features.activityType, .package_drop)
        XCTAssertTrue(features.duration < 10)
        XCTAssertTrue(features.energy < 0.5)
        print("✅ Package drop: duration=\(features.duration)s, energy=\(String(format: "%.2f", features.energy))")
    }
    
    // MARK: - Pet Motion Detection
    
    func testPetMotion() {
        // Erratic, low-medium energy
        let rawData = [0.1, 0.5, 0.2, 0.6, 0.1, 0.4, 0.2, 0.5]
        let features = MotionAnalyzer.analyzeMotionVector(
            rawData,
            sampleRate: 10.0,
            duration: 12.0
        )
        
        XCTAssertEqual(features.activityType, .pet)
        print("✅ Pet motion: duration=\(features.duration)s, energy=\(String(format: "%.2f", features.energy))")
    }
    
    // MARK: - Loitering Detection
    
    func testLoiteringMotion() {
        // Long duration, sustained medium energy
        let rawData = Array(repeating: 0.4, count: 40)
        let features = MotionAnalyzer.analyzeMotionVector(
            rawData,
            sampleRate: 10.0,
            duration: 35.0
        )
        
        XCTAssertEqual(features.activityType, .loitering)
        XCTAssertTrue(features.duration > 30)
        print("✅ Loitering: duration=\(features.duration)s, energy=\(String(format: "%.2f", features.energy))")
    }
    
    // MARK: - Walking Detection
    
    func testWalkingMotion() {
        // Medium energy, medium duration
        let rawData = [0.5, 0.6, 0.5, 0.6, 0.5, 0.6, 0.5, 0.6]
        let features = MotionAnalyzer.analyzeMotionVector(
            rawData,
            sampleRate: 10.0,
            duration: 8.0
        )
        
        XCTAssertEqual(features.activityType, .walking)
        print("✅ Walking: duration=\(features.duration)s, energy=\(String(format: "%.2f", features.energy))")
    }
    
    // MARK: - Running Detection
    
    func testRunningMotion() {
        // High energy
        let rawData = [0.8, 0.9, 0.8, 0.9, 0.8]
        let features = MotionAnalyzer.analyzeMotionVector(
            rawData,
            sampleRate: 10.0,
            duration: 5.0
        )
        
        XCTAssertEqual(features.activityType, .running)
        XCTAssertTrue(features.energy > 0.7)
        print("✅ Running: duration=\(features.duration)s, energy=\(String(format: "%.2f", features.energy))")
    }
    
    // MARK: - Stationary Detection
    
    func testStationaryMotion() {
        // Very low energy, short duration
        let rawData = [0.05, 0.03, 0.04]
        let features = MotionAnalyzer.analyzeMotionVector(
            rawData,
            sampleRate: 10.0,
            duration: 1.5
        )
        
        XCTAssertEqual(features.activityType, .stationary)
        print("✅ Stationary: duration=\(features.duration)s, energy=\(String(format: "%.2f", features.energy))")
    }
    
    // MARK: - Metadata Analysis
    
    func testAnalyzeFromMetadata() {
        let metadata: [String: Any] = [
            "duration": 3.0,
            "energy": 0.25
        ]
        
        let features = MotionAnalyzer.analyzeFromMetadata(metadata)
        
        XCTAssertEqual(features.activityType, .package_drop)
        XCTAssertEqual(features.duration, 3.0)
        XCTAssertTrue(features.confidence < 1.0, "Metadata-based analysis should have lower confidence")
        print("✅ Metadata analysis: \(features.activityType.rawValue)")
    }
    
    // MARK: - Energy Calculation
    
    func testEnergyCalculation() {
        // Test with known vector
        let rawData = [0.3, 0.4, 0.5]
        let features = MotionAnalyzer.analyzeMotionVector(
            rawData,
            sampleRate: 10.0,
            duration: 3.0
        )
        
        // Energy should be calculated correctly
        XCTAssertTrue(features.energy > 0)
        XCTAssertTrue(features.energy <= 1.0)
        XCTAssertTrue(features.vectorNorm > 0)
        print("✅ Energy: \(String(format: "%.3f", features.energy)), Norm: \(String(format: "%.3f", features.vectorNorm))")
    }
}



