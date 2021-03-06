// swift-tools-version:5.1
import PackageDescription

let package = Package(
  name: "swift-driver",
  platforms: [
    .macOS(.v10_15),
  ],
  products: [
    .executable(
      name: "swift-driver",
      targets: ["swift-driver"]),
    .executable(
      name: "swift-help",
      targets: ["swift-help"]),
    .library(
      name: "SwiftDriver",
      targets: ["SwiftDriver"]),
    .library(
      name: "SwiftOptions",
      targets: ["SwiftOptions"]),
    .library(
      name: "FlockClient",
      targets: ["FlockClient"]),
    .library(
      name: "FlockServer",
      targets: ["FlockServer"]),
    .executable(
      name: "flock-server",
      targets: ["flock-server"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-tools-support-core.git", .branch("master")),
    .package(url: "https://github.com/apple/swift-llbuild.git", .branch("master")),
    .package(url: "https://github.com/jpsim/Yams.git", .branch("master")),
    .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
  ],
  targets: [
    /// The driver library.
    .target(
      name: "SwiftDriver",
      dependencies: ["SwiftOptions", "SwiftToolsSupport-auto", "llbuildSwift", "Yams", "FlockClient"]),
    .testTarget(
      name: "SwiftDriverTests",
      dependencies: ["SwiftDriver", "swift-driver"]),

    /// The options library.
    .target(
      name: "SwiftOptions",
      dependencies: ["SwiftToolsSupport-auto"]),
    .testTarget(
      name: "SwiftOptionsTests",
      dependencies: ["SwiftOptions"]),

    /// The primary driver executable.
    .target(
      name: "swift-driver",
      dependencies: ["SwiftDriver"]),

    /// The help executable.
    .target(
      name: "swift-help",
      dependencies: ["SwiftOptions"]),

    /// The `makeOptions` utility (for importing option definitions).
    .target(
      name: "makeOptions",
      dependencies: []),

    /// Flock client
    .target(
      name: "FlockClient",
      dependencies: ["SwiftToolsSupport-auto", "Yams"]),
    .testTarget(
      name: "FlockClientTests",
      dependencies: ["FlockClient"]),

    /// Flock server
    .target(
      name: "FlockServer",
      dependencies: ["SwiftToolsSupport-auto", "Yams", "NIO"]),
    .target(
      name: "flock-server",
      dependencies: ["FlockServer"]),
    .testTarget(
      name: "FlockServerTests",
      dependencies: ["FlockServer"]),
  ],
  cxxLanguageStandard: .cxx14
)
