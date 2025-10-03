// swift-tools-version:5.7
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
            targets: ["NovinIntelligence"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NovinIntelligence",
            dependencies: [],
            path: "intelligence"),
        .testTarget(
            name: "NovinIntelligenceTests",
            dependencies: ["NovinIntelligence"],
            path: "intelligenceTests"),
    ]
)
