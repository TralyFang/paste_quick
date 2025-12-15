// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PasteQuick",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PasteQuick",
            targets: ["PasteQuick"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PasteQuick",
            dependencies: [],
            exclude: [
                "assets"
            ]
        ),
    ]
)

