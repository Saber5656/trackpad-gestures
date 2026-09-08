// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "TrackpadGestures", platforms: [.macOS("15.1")],
    products: [.library(name: "TrackpadCore", targets: ["TrackpadCore"])],
    targets: [.target(name: "TrackpadCore"),
              .testTarget(name: "TrackpadCoreTests", dependencies: ["TrackpadCore"], resources: [.copy("Fixtures")])],
    swiftLanguageModes: [.v5])
