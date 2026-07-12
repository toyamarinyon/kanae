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
    ]
)
