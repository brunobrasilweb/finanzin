// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Finanzin",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "FinanzinCore", targets: ["FinanzinCore"]),
        .library(name: "FinanzinUI", targets: ["FinanzinUI"]),
    ],
    targets: [
        .target(
            name: "FinanzinCore",
            path: "Sources/FinanzinCore"
        ),
        .target(
            name: "FinanzinUI",
            dependencies: ["FinanzinCore"],
            path: "Sources/FinanzinUI"
        ),
        .executableTarget(
            name: "FinanzinCoreTests",
            dependencies: ["FinanzinCore"],
            path: "Tests/FinanzinCoreTests"
        ),
        .executableTarget(
            name: "FinanzinDemo",
            dependencies: ["FinanzinUI"],
            path: "Sources/FinanzinDemo"
        ),
    ]
)
