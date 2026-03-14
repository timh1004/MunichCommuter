// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MunichCommuterKit",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v14),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "MunichCommuterKit",
            targets: ["MunichCommuterKit"]
        ),
    ],
    targets: [
        .target(
            name: "MunichCommuterKit"
        ),
    ]
)
