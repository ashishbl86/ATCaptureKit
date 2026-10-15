// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "ATCaptureKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "ATCaptureKit",
            targets: ["ATCaptureKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/atlyslabs/ATUIKit", from: "1.3.7"),
    ],
    targets: [
        .target(
            name: "ATCaptureKit",
            dependencies: [
                .product(name: "ATUIKit", package: "ATUIKit"),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
        ),
    ]
)
