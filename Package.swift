// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "appattest-swift",
  platforms: [
    .macOS(.v14),
    .iOS(.v17),
  ],
  products: [
    .library(
      name: "AppAttest",
      targets: ["AppAttest"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/outfoxx/PotentCodables", from: "3.5.0"),
    .package(url: "https://github.com/apple/swift-certificates", from: "1.5.0"),
  ],
  targets: [
    .target(
      name: "AppAttest",
      dependencies: [
        .product(name: "PotentCodables", package: "PotentCodables"),
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
