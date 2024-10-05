// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Server",
  platforms: [
    .macOS(.v14)
  ],
  dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.1"),
    .package(name: "appattest-swift", path: "../../../appattest-swift"),
  ],
  targets: [
    .executableTarget(
      name: "Server",
      dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "AppAttest", package: "appattest-swift"),
      ]
    ),
  ]
)
