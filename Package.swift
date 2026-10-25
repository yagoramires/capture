// swift-tools-version:6.0
import Foundation
import PackageDescription

// NeyKit vem do checkout do neyhub ao lado (ou NEYHUB_PATH). A identidade de `.package(path:)` é o nome
// da pasta em minúsculas, então derivamos dela: funciona com worktrees.
let neyhub = ProcessInfo.processInfo.environment["NEYHUB_PATH"] ?? "../neyhub"
let hub = URL(fileURLWithPath: neyhub).lastPathComponent.lowercased()
let swift5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "Capture",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Capture", targets: ["Capture"]),
        .library(name: "CapturePlugin", type: .dynamic, targets: ["CapturePlugin"]),
    ],
    dependencies: [.package(path: neyhub)],
    targets: [
        .target(
            name: "CaptureCore",
            dependencies: [.product(name: "NeyKit", package: hub)],
            path: "Sources/CaptureCore",
            swiftSettings: swift5
        ),
        .executableTarget(
            name: "Capture",
            dependencies: ["CaptureCore", .product(name: "NeyKitApp", package: hub)],
            path: "Sources/Capture",
            swiftSettings: swift5
        ),
        // Plugin do NeyHub: nunca linka NeyKitApp (classes duplicadas no processo do NeyHub).
        .target(name: "CapturePlugin", dependencies: ["CaptureCore", .product(name: "NeyKit", package: hub)], path: "Sources/CapturePlugin", swiftSettings: swift5),
    ]
)
