// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BowlingCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "BowlingCore", targets: ["BowlingCore"]),
        // Demo games for previews, the BowlingData demo store, and StatsEngine tests.
        .library(name: "BowlingFixtures", targets: ["BowlingFixtures"]),
    ],
    targets: [
        .target(name: "BowlingCore"),
        .target(name: "BowlingFixtures", dependencies: ["BowlingCore"]),
        .testTarget(name: "BowlingCoreTests", dependencies: ["BowlingCore", "BowlingFixtures"]),
    ]
)
