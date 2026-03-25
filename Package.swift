// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SARKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Full SDK — main app (StoreKit + AdServices + sessions)
        .library(
            name: "SARKit",
            targets: ["SARKit"]
        ),
        // Core SDK — extensions (sessions + custom events only, no StoreKit)
        .library(
            name: "SARKitCore",
            targets: ["SARKitCore"]
        )
    ],
    targets: [
        .target(
            name: "SARKitCore",
            dependencies: [],
            path: "Sources/SARKitCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=minimal")
            ]
        ),
        .target(
            name: "SARKit",
            dependencies: ["SARKitCore"],
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
