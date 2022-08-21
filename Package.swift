// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend",
        "-warn-concurrency",
    ])
]

let package = Package(
    name: "AsyncChannelKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v12),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "AsyncChannelKit",
            targets: ["AsyncChannelKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/brennanMKE/AsyncTesting.git", exact: "0.0.5")
    ],
    targets: [
        .target(
            name: "AsyncChannelKit",
            dependencies: []),
        .testTarget(
            name: "AsyncChannelKitTests",
            dependencies: ["AsyncChannelKit", "AsyncTesting"],
            swiftSettings: swiftSettings
        ),
    ]
)
