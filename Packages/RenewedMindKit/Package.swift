// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "RenewedMindKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RenewedMindKit", targets: ["RenewedMindKit"]),
    ],
    targets: [
        .target(
            name: "RenewedMindKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "RenewedMindKitTests",
            dependencies: ["RenewedMindKit"]
        ),
    ]
)
