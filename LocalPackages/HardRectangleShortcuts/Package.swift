// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HardRectangleShortcuts",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "HardRectangleShortcuts", type: .static, targets: ["HardRectangleShortcuts"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HardRectangleShortcuts",
            dependencies: [],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "HardRectangleShortcutsTests",
            dependencies: ["HardRectangleShortcuts"],
            resources: [.process("Fixtures")]
        )
    ]
)
