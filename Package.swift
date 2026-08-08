// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Abigent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AbigentCore", targets: ["AbigentCore"]),
        .library(name: "AbigentCodex", targets: ["AbigentCodex"])
    ],
    targets: [
        .target(name: "AbigentCore", path: "AppSources/AbigentCore"),
        .target(
            name: "AbigentCodex",
            dependencies: ["AbigentCore"],
            path: "AppSources/AbigentCodex"
        ),
        .testTarget(name: "AbigentCoreTests", dependencies: ["AbigentCore"]),
        .testTarget(name: "AbigentCodexTests", dependencies: ["AbigentCodex"])
    ]
)
