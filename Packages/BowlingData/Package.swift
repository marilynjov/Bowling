// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BowlingData",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "BowlingData", targets: ["BowlingData"]),
    ],
    dependencies: [
        .package(path: "../BowlingCore"),
    ],
    targets: [
        .target(name: "BowlingData", dependencies: ["BowlingCore"]),
        .testTarget(name: "BowlingDataTests", dependencies: [
            "BowlingData",
            .product(name: "BowlingFixtures", package: "BowlingCore"),
        ]),
    ]
)
