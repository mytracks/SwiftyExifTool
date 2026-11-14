// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftyExifTool",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "SwiftyExifTool", targets: ["SwiftyExifTool"]),
    ],
    targets: [
        .target(name: "SwiftyExifTool"),

        // Development only: synthetic fixture builder and catalogue.
        .target(name: "FixtureKit"),

        // Development only: compares reading results with exiftool snapshots
        // (synthetic fixtures and the sample corpus). Not a product.
        .target(
            name: "ConformanceKit",
            dependencies: ["SwiftyExifTool"]
        ),

        // Development only (macOS): generates fixtures, records exiftool
        // snapshots and runs the conformance tooling.
        .executableTarget(
            name: "fixtures",
            dependencies: ["FixtureKit", "ConformanceKit", "SwiftyExifTool"]
        ),

        .testTarget(
            name: "SwiftyExifToolTests",
            dependencies: ["SwiftyExifTool", "FixtureKit", "ConformanceKit"],
            resources: [
                .copy("Fixtures"),
                .copy("Snapshots"),
            ]
        ),
    ]
)
