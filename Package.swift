// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Abigent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AbigentCore", targets: ["AbigentCore"])
    ],
    targets: [
        .target(name: "AbigentCore"),
        .testTarget(name: "AbigentCoreTests", dependencies: ["AbigentCore"])
    ]
)

