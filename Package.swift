// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexPulse",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexPulse", targets: ["CodexPulse"]),
        .library(name: "CodexPulseCore", targets: ["CodexPulseCore"])
    ],
    targets: [
        .target(
            name: "CodexPulseCore"
        ),
        .executableTarget(
            name: "CodexPulse",
            dependencies: ["CodexPulseCore"],
            path: "Sources/CodexPulse",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "CodexPulseTests",
            dependencies: ["CodexPulseCore"]
        )
    ]
)
