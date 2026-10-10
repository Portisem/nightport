// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GamingMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "gmac", targets: ["gmac"]),
        .library(name: "GMCore", targets: ["GMCore"]),
    ],
    targets: [
        .target(name: "GMCore"),
        .executableTarget(name: "gmac", dependencies: ["GMCore"]),
    ]
)
