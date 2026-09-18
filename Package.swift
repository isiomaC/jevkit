// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JevKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "JevKit", targets: ["JevKit"]),
        .executable(name: "JevCLI", targets: ["JevCLI"]),
    ],
    targets: [
        .target(name: "JevKit"),
        .executableTarget(name: "JevCLI", dependencies: ["JevKit"]),
        .testTarget(name: "JevKitTests", dependencies: ["JevKit"]),
    ]
)
