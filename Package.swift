// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "TrackpadGestures", platforms: [.macOS("15.1")],
    products: [.library(name: "TrackpadCore", targets: ["TrackpadCore"]),
               .executable(name: "TrackpadProbe", targets: ["TrackpadProbe"])],
    targets: [.target(name: "TrackpadCore"), .target(name: "MacPlatform", dependencies: ["TrackpadCore"]),
              .executableTarget(name: "TrackpadProbe", dependencies: ["MacPlatform"]),
              .testTarget(name: "TrackpadCoreTests", dependencies: ["TrackpadCore"], resources: [.copy("Fixtures")]),
              .testTarget(name: "MacPlatformTests", dependencies: ["MacPlatform"])],
    swiftLanguageModes: [.v5])
