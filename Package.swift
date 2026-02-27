// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LaterLogic",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LaterLogic",
            targets: ["LaterLogic"]
        )
    ],
    targets: [
        .target(
            name: "LaterLogic"
        ),
        .testTarget(
            name: "LaterLogicTests",
            dependencies: ["LaterLogic"]
        )
    ]
)
