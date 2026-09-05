// swift-tools-version: 5.9
// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 AIPDF contributors
import PackageDescription

let package = Package(
    name: "AIPDF",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AIPDF", targets: ["AIPDF"]), .executable(name: "VisionHelper", targets: ["VisionHelper"]), .executable(name: "WebHelper", targets: ["WebHelper"])],
    targets: [.executableTarget(name: "AIPDF"), .executableTarget(name: "VisionHelper"), .executableTarget(name: "WebHelper")]
)
