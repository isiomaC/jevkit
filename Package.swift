// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JevKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "JevKit", targets: ["JevKit"]),
    ],
    targets: [
        .target(name: "JevKit"),
        .testTarget(name: "JevKitTests", dependencies: ["JevKit"]),
    ]
)
