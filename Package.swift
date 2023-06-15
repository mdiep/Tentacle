// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "Tentacle",
    products: [
        .library(name: "Tentacle", targets: ["Tentacle"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "7.1.1"),
    ],
    targets: [
        .target(name: "Tentacle", dependencies: ["ReactiveSwift"]),
        .testTarget(
            name: "TentacleTests", 
            dependencies: ["Tentacle"], 
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
