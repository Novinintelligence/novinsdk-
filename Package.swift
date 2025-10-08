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
            name: "Novin",
            targets: ["NovinIntelligence"]
        ),
        .executable(
            name: "novin-prod",
            targets: ["NovinProd"]
        ),
        .executable(
            name: "novin-bridge",
            targets: ["NovinBridge"]
        )
    ],
    dependencies: [
        // Only used by the bridge executable; the core library remains dependency-free
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.58.0")
    ],
    targets: [
        .target(
            name: "NovinIntelligence",
            dependencies: [],
            path: "Sources/NovinIntelligence",
            exclude: [
                // Exclude all Python-related files to ensure Swift-only SDK
                "Resources/python",
                "Resources/novin_ai_bridge.py",
                "Resources/requirements.txt",
                "Resources/install_dependencies.py"
            ],
            resources: [
                .copy("Rules")
            ],
            plugins: []
        ),
        .executableTarget(
            name: "NovinProd",
            dependencies: ["NovinIntelligence"],
            path: "Sources/NovinProd"
        ),
        .executableTarget(
            name: "NovinBridge",
            dependencies: [
                "NovinIntelligence",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ],
            path: "Sources/NovinBridge"
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
