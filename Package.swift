// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "MCV",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.19"))
    ],
    targets: [
        .executableTarget(
            name: "MCV",
            dependencies: ["ZIPFoundation"],
            path: "Sources",
            resources: [
                .process("mcv_icon.png")
            ]
        )
    ]
)
