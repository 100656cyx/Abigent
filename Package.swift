// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Abigent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AbigentCore", targets: ["AbigentCore"]),
        .library(name: "AbigentCodex", targets: ["AbigentCodex"]),
        .library(name: "AbigentPersistence", targets: ["AbigentPersistence"]),
        .library(name: "AbigentRuntime", targets: ["AbigentRuntime"]),
        .executable(name: "abigent-diagnostics", targets: ["AbigentDiagnostics"]),
        .executable(name: "Abigent", targets: ["AbigentApp"])
    ],
    targets: [
        .target(name: "AbigentCore", path: "AppSources/AbigentCore"),
        .systemLibrary(name: "CSQLite", path: "AppSources/CSQLite"),
        .target(
            name: "AbigentPersistence",
            dependencies: ["AbigentCore", "CSQLite"],
            path: "AppSources/AbigentPersistence"
        ),
        .target(
            name: "AbigentRuntime",
            dependencies: ["AbigentCore", "AbigentPersistence"],
            path: "AppSources/AbigentRuntime"
        ),
        .target(
            name: "AbigentCodex",
            dependencies: ["AbigentCore"],
            path: "AppSources/AbigentCodex"
        ),
        .executableTarget(
            name: "AbigentDiagnostics",
            dependencies: ["AbigentCore", "AbigentCodex"],
            path: "AppSources/AbigentDiagnostics"
        ),
        .executableTarget(
            name: "AbigentApp",
            dependencies: ["AbigentCore", "AbigentCodex", "AbigentPersistence", "AbigentRuntime"],
            path: "AppSources/AbigentApp"
        ),
        .testTarget(name: "AbigentCoreTests", dependencies: ["AbigentCore"]),
        .testTarget(name: "AbigentCodexTests", dependencies: ["AbigentCodex"]),
        .testTarget(name: "AbigentPersistenceTests", dependencies: ["AbigentPersistence"]),
        .testTarget(
            name: "AbigentRuntimeTests",
            dependencies: ["AbigentRuntime", "AbigentCore", "AbigentPersistence"]
        )
    ]
)
