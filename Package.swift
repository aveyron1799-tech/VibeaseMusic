// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VibeaseMusic",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("15.0")],
    products: [
        .executable(name: "VibeaseMusic", targets: ["VibeaseMusic"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.5"),
    ],
    targets: [
        .executableTarget(
            name: "VibeaseMusic",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/VibeaseMusic",
            // .lproj tables are copied into Contents/Resources by build-app.sh
            // so Bundle.main lookups work without Bundle.module plumbing.
            exclude: ["Resources"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                // Sparkle.framework is embedded in Contents/Frameworks by Scripts/build-app.sh.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
    ]
)
