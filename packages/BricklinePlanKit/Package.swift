// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BricklinePlanKit",
    platforms: [
        .macOS("15.0"),
        .iOS("18.0"),
        .watchOS("11.0")
    ],
    products: [
        .library(name: "BricklinePlanKit", targets: ["BricklinePlanKit"])
    ],
    targets: [
        .target(
            name: "BricklinePlanKit",
            path: "Sources/BricklinePlanKit"
        ),
        .testTarget(
            name: "BricklinePlanKitTests",
            dependencies: ["BricklinePlanKit"],
            path: "Tests/BricklinePlanKitTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
