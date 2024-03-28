// swift-tools-version: 5.10

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
        .package(url: "https://github.com/apple/swift-syntax.git", "509.0.0"..<"999.0.0"),
        .package(url: "https://github.com/swiftwasm/WasmKit.git", from: "0.0.3"),
    ],
    targets: [
        .target(
            name: "SuperFastPluginRaw",
            dependencies: [
                .product(name: "SwiftCompilerPluginMessageHandling", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SuperFastPluginHost",
            dependencies: [
                "WasmKit",
                .product(name: "WASI", package: "WasmKit")
            ]
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
