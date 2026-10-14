// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BowlingCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "BowlingCore", targets: ["BowlingCore"]),
    ],
    targets: [
        .target(name: "BowlingCore"),
        .testTarget(name: "BowlingCoreTests", dependencies: ["BowlingCore"]),
    ]
)
