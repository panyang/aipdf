// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIPDF",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AIPDF", targets: ["AIPDF"]), .executable(name: "VisionHelper", targets: ["VisionHelper"]), .executable(name: "WebHelper", targets: ["WebHelper"])],
    targets: [.executableTarget(name: "AIPDF"), .executableTarget(name: "VisionHelper"), .executableTarget(name: "WebHelper")]
)
