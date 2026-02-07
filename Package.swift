// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PolePlayer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PolePlayerApp", targets: ["PolePlayerApp"]),
        .library(name: "PlayerCore", targets: ["PlayerCore"]),
        .library(name: "DecodeKit", targets: ["DecodeKit"]),
        .library(name: "RenderCore", targets: ["RenderCore"]),
        .library(name: "Review", targets: ["Review"]),
        .library(name: "Library", targets: ["Library"]),
        .library(name: "Export", targets: ["Export"])
    ],
    targets: [
        .executableTarget(
            name: "PolePlayerApp",
            dependencies: [
                "PlayerCore",
                "DecodeKit",
                "RenderCore",
                "Review",
                "Library",
                "Export"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "PlayerCore",
            dependencies: ["DecodeKit"]
        ),
        .target(name: "DecodeKit"),
        .target(name: "RenderCore"),
        .target(name: "Review"),
        .target(name: "Library"),
        .target(name: "Export"),
        .testTarget(
            name: "PlayerCoreTests",
            dependencies: ["PlayerCore"]
        ),
        .testTarget(
            name: "RenderCoreTests",
            dependencies: ["RenderCore"]
        ),
        .testTarget(
            name: "ReviewTests",
            dependencies: ["Review"]
        )
    ]
)
