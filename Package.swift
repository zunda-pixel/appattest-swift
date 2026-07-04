// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "appattest-swift",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),
  ],
  products: [
    .library(
      name: "AppAttest",
      targets: ["AppAttest"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/brokenhandsio/swift-cbor", from: "0.0.1"),
    .package(url: "https://github.com/apple/swift-certificates", from: "1.19.0"),
  ],
  targets: [
    .target(
      name: "AppAttest",
      dependencies: [
        .product(name: "CBOR", package: "swift-cbor"),
        .product(name: "X509", package: "swift-certificates"),
      ],
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "AppAttestTests",
      dependencies: ["AppAttest"]
    ),
  ]
)
