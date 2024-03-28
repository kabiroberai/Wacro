// swift-tools-version: 5.10

import Foundation
import PackageDescription
import CompilerPluginSupport

let rawMode = ProcessInfo.processInfo.environment["WACRO_RAW"] == "1"
let webkitMode = ProcessInfo.processInfo.environment["WEBKIT_RUNNER"] == "1"

let package = Package(
    name: "Wacro",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(
            name: "WacroPluginHost",
            targets: ["WacroPluginHost"]
        ),
        .library(
            name: "WacroPluginRaw",
            targets: ["WacroPluginRaw"]
        ),
    ],
    dependencies: (rawMode ? [
        .package(url: "https://github.com/apple/swift-syntax.git", "509.0.0"..<"999.0.0"),
    ] : []) + (webkitMode ? [] : [
        .package(url: "https://github.com/kabiroberai/WasmKit.git", branch: "slim"),
    ]),
    targets: [
        .target(
            name: "WacroPluginRaw",
            dependencies: rawMode ? [
                .product(name: "SwiftCompilerPluginMessageHandling", package: "swift-syntax"),
            ] : []
        ),
        .target(
            name: "WacroPluginHost",
            dependencies: webkitMode ? [] : [
                "WasmKit",
                .product(name: "WASI", package: "WasmKit")
            ],
            swiftSettings: webkitMode ? [
                .define("WEBKIT_RUNNER")
            ] : []
        ),
        .testTarget(
            name: "WacroPluginHostTests",
            dependencies: [
                "WacroPluginHost",
            ]
        ),
    ]
)
