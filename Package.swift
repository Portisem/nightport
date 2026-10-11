// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GamingMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "gmac", targets: ["gmac"]),
        .executable(name: "GamingMacApp", targets: ["GamingMacApp"]),
        .library(name: "GMCore", targets: ["GMCore"]),
    ],
    targets: [
        .target(name: "GMCore"),
        .executableTarget(name: "gmac", dependencies: ["GMCore"]),
        .executableTarget(name: "GamingMacApp", dependencies: ["GMCore"]),
    ]
)
