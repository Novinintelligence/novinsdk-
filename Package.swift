// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NovinFramework",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Novin",
            targets: ["Novin"]
        )
    ],
    targets: [
        .target(
            name: "Novin",
            dependencies: [],
            path: "Sources/Novin"
        )
    ]
)
