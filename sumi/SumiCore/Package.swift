// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SumiCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SumiCore", targets: ["SumiCore"]),
    ],
    targets: [
        .target(name: "SumiCore"),
        .testTarget(name: "SumiCoreTests", dependencies: ["SumiCore"]),
    ]
)
