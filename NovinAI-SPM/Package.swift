// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NovinAI",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "NovinAI", targets: ["NovinAI"]),
    ],
    dependencies: [
        // Use local vendored checkout to avoid locked remote manifest issues
        .package(path: "Vendor/Python-iOS")
    ],
    targets: [
        .target(
            name: "NovinAI",
            dependencies: [
                .product(name: "Python-iOS", package: "Python-iOS")
            ],
            resources: [
                .copy("Sources/NovinAI/ProtectedPython"),
                .copy("Sources/NovinAI/Python.xcframework"),
                .copy("Sources/NovinAI/data")
            ],
            swiftSettings: [
                .define("PLATFORM_IOS", .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "NovinAITests",
            dependencies: ["NovinAI"],
            resources: [
                .process("Fixtures")
            ]
        ),
    ]
)
