// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Example",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .executable(
            name: "ExampleRaw",
            targets: ["ExampleRaw"]
        ),
        .executable(
            name: "ExampleClient",
            targets: ["ExampleClient"]
        ),
    ],
    dependencies: [
        .package(name: "SuperFast", path: "..")
    ],
    targets: [
        .executableTarget(
            name: "ExampleClient",
            dependencies: [
                "ExampleHost"
            ]
        ),
        .executableTarget(
            name: "ExampleRaw",
            dependencies: [
                .product(name: "SuperFastPluginRaw", package: "SuperFast"),
            ]
        ),
        .target(
            name: "ExampleHostContainer",
            resources: [
                .copy("ExampleRaw.wasm")
            ]
        ),
        .macro(
            name: "ExampleHost",
            dependencies: [
                .product(name: "SuperFastPluginHost", package: "SuperFast"),
                "ExampleHostContainer",
            ]
        ),
    ]
)
