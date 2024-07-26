// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "QuicVarInt",
    products: [
        .library(
            name: "QuicVarInt",
            targets: ["QuicVarInt"])
    ],
    targets: [
        .target(
            name: "QuicVarInt"),
        .testTarget(
            name: "QuicVarIntTests",
            dependencies: ["QuicVarInt"])
    ]
)
