// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GamingMac",
    // Los textos del código están en español; en.lproj trae la traducción al inglés.
    defaultLocalization: "es",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "gmac", targets: ["gmac"]),
        .executable(name: "GamingMacApp", targets: ["GamingMacApp"]),
        .library(name: "GMCore", targets: ["GMCore"]),
    ],
    targets: [
        .target(name: "GMCore"),
        .executableTarget(name: "gmac", dependencies: ["GMCore"]),
        // build-app.sh copia los .lproj del bundle de recursos a Nightport.app/Contents/Resources:
        // la app busca sus textos en Bundle.main (también los de GMCore), nunca en Bundle.module.
        .executableTarget(name: "GamingMacApp", dependencies: ["GMCore"], resources: [.process("Resources")]),
    ]
)
