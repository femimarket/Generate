// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "Generate2",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "Generate2",
            targets: ["Generate2"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/femimarket/swiftapi", from: "0.1.0"),
        .package(url: "https://github.com/atelier-socle/swift-audio-marker", from: "0.1.1"),
    ],
    targets: [
        .target(
            name: "Generate2",
            dependencies: [
                .product(name: "Api", package: "swiftapi"),
                .product(name: "AudioMarker", package: "swift-audio-marker"),
            ],
            path: ".",
            exclude: [
                // App-target-only: standalone @main entry, asset catalog,
                // bundled images/audio, and the Package.swift itself.
                "Generate2App.swift",
                "Assets.xcassets",
                "Generate",
                "Package.swift",
                "ContentViewOld.swift",
                "v1.md",
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
