// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TagFlow",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "TagFlow",
            path: "Sources/TagFlow",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
