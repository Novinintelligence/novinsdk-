// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NovinIntelligence",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "NovinIntelligence",
            targets: ["NovinIntelligence"]
        )
    ],
    targets: [
        .target(
            name: "NovinIntelligence",
            dependencies: [],
            path: "Sources/NovinIntelligence",
            exclude: [
                "Resources/python"
            ],
            resources: [
                .copy("Rules")
            ],
            plugins: []
        ),
        .testTarget(
            name: "NovinIntelligenceTests",
            dependencies: ["NovinIntelligence"],
            exclude: [
                // Legacy Python-based tests
                "test_crime_intelligence.py",
                "test_neural_network.py",
                "test_security_system.py",
                "run_tests.py",
                "simple_test.py",
                // Legacy Swift tests referencing removed ML/Python APIs
                "FullSDKBattleTest.swift",
                "NovinIntelligenceTests.swift",
                "ProductionBridgeTests.swift"
            ]
        )
    ]
)
