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

        // Development only (macOS): generates fixtures and records exiftool snapshots.
        .executableTarget(
            name: "fixtures",
            dependencies: ["FixtureKit"]
        ),

        .testTarget(
            name: "SwiftyExifToolTests",
            dependencies: ["SwiftyExifTool", "FixtureKit"],
            resources: [
                .copy("Fixtures"),
                .copy("Snapshots"),
            ]
        ),
    ]
)
