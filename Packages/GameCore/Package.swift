// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "GameCore",
            targets: ["GameCore"]
        ),
    ],
    targets: [
        .target(
            name: "GameCore"
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
