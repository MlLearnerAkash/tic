// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tic",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tic",
            path: "Sources/Tic"
        )
    ]
)
