// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "kanae",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "kanae", targets: ["Kanae"]),
    ],
    targets: [
        .executableTarget(
            name: "Kanae",
            path: "Sources/Kanae"
        ),
        .plugin(
            name: "KanaeBuildDevPlugin",
            capability: .command(
                intent: .custom(
                    verb: "kanae-build-dev",
                    description: "Build Kanae's debug app bundle for local development."
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "Create the development app bundle in .build/dev."
                    ),
                ]
            ),
            path: "Plugins/KanaeBuildDevPlugin"
        ),
    ]
)
