// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SARKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SARKit",
            targets: ["SARKit"]
        )
    ],
    targets: [
        .target(
            name: "SARKit",
            dependencies: [],
            path: "Sources/SARKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=minimal")
            ]
        ),
        .testTarget(
            name: "SARKitTests",
            dependencies: ["SARKit"]
        )
    ]
)
