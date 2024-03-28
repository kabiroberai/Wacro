// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SuperFast",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(
            name: "SuperFastPluginRaw",
            targets: ["SuperFastPluginRaw"]
        ),
        .library(
            name: "SuperFastPluginHost",
            targets: ["SuperFastPluginHost"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.1")
    ],
    targets: [
        .target(
            name: "SuperFastPluginRaw",
            dependencies: [
                .product(name: "SwiftCompilerPluginMessageHandling", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SuperFastPluginHost"
        ),
        .testTarget(
            name: "SuperFastPluginHostTests",
            dependencies: [
                "SuperFastPluginHost",
                .product(name: "SwiftCompilerPluginMessageHandling", package: "swift-syntax"),
            ]
        ),
    ]
)
