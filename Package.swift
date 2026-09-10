// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Electron",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Electron",
            path: "Sources/Electron"
        ),
        .testTarget(
            name: "ElectronTests",
            dependencies: ["Electron"],
            path: "Tests/ElectronTests"
        )
    ]
)
