// swift-tools-version: 5.9
import PackageDescription

var targets: [Target] = [
    .target(name: "PixNabCore", path: "Sources/PixNabCore"),
    .testTarget(name: "PixNabCoreTests", dependencies: ["PixNabCore"], path: "Tests/PixNabCoreTests"),
    .executableTarget(name: "PixNabCLI", dependencies: ["PixNabCore"], path: "Sources/PixNabCLI")
]
var products: [Product] = [ .library(name: "PixNabCore", targets: ["PixNabCore"]),
    .executable(name: "pixnab-cli", targets: ["PixNabCLI"]) ]
#if os(macOS)
targets.append(.executableTarget(name: "PixNab", dependencies: ["PixNabCore"], path: "Sources/PixNab", exclude: ["Resources"]))
products.append(.executable(name: "PixNab", targets: ["PixNab"]))
#endif
let package = Package(
    name: "PixNab", platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
