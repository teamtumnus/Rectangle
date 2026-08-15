// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RectangleShortcuts",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "RectangleShortcuts", type: .static, targets: ["RectangleShortcuts"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RectangleShortcuts",
            dependencies: [],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "RectangleShortcutsTests",
            dependencies: ["RectangleShortcuts"]
        )
    ]
)
