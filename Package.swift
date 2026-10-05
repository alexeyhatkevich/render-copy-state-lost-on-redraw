// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RenderCopyState",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "RenderCopyState", targets: ["RenderCopyState"]),
    ],
    targets: [
        .target(name: "RenderCopyState"),
        .testTarget(name: "RenderCopyStateTests", dependencies: ["RenderCopyState"]),
    ]
)
