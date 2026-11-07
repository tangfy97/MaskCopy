// swift-tools-version: 6.0
// The engine (MaskeCore) and `maske`, a command-line tool that makes the synthetic test
// documents and checks the engine against them. The iOS app is built from project.yml.
import PackageDescription

let package = Package(
    name: "Maske",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "MaskeCore", targets: ["MaskeCore"]),
        .executable(name: "maske", targets: ["maske"]),
    ],
    targets: [
        .target(name: "MaskeCore"),
        .executableTarget(name: "maske", dependencies: ["MaskeCore"]),
        .testTarget(name: "MaskeCoreTests", dependencies: ["MaskeCore"]),
    ],
    swiftLanguageModes: [.v5]
)
