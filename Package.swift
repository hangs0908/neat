// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NeatPolicy",
    platforms: [.macOS("27.0")],
    products: [.library(name: "NeatPolicy", targets: ["NeatPolicy"])],
    targets: [
        .target(name: "NeatPolicy", path: "upstream/Thaw/Neat"),
        .testTarget(name: "NeatPolicyTests", dependencies: ["NeatPolicy"]),
    ]
)
