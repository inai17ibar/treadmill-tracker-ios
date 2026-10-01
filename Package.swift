// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TreadmillTracker",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "TreadmillKit", targets: ["TreadmillKit"])
    ],
    targets: [
        .target(
            name: "TreadmillKit",
            path: "Sources/TreadmillKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "TreadmillKitTests",
            dependencies: ["TreadmillKit"],
            path: "Tests/TreadmillKitTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
