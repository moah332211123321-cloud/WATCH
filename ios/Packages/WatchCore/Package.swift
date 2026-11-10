// swift-tools-version:5.9
import PackageDescription

// Pure-Swift protocol layer: framing, commands, decoders, drivers. Foundation only, so it can be
// unit-tested with `swift test` on any machine with a Swift toolchain (CI: macOS runner).
let package = Package(
    name: "WatchCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "WatchCore", targets: ["WatchCore"])],
    targets: [
        .target(name: "WatchCore"),
        .testTarget(name: "WatchCoreTests", dependencies: ["WatchCore"]),
    ]
)
