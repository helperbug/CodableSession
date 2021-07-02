// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodableSession",
    products: [
        .library(
            name: "CodableSession",
            targets: ["CodableSession"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "CodableSession",
            dependencies: []),
        .testTarget(
            name: "CodableSessionTests",
            dependencies: ["CodableSession"]),
    ]
)
