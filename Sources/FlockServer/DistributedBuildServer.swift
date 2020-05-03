//===------------ DistributedBuildServer.swift - Flock Server -------------===//
//
// Copyright (c) 2020 Roopesh Chander <http://roopc.net/>
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import TSCBasic
import NIO

public class DistributedBuildServer {
  private let group: MultiThreadedEventLoopGroup
  private let config: ServerConfiguration

  private let swiftPathsByVersionString: [String: AbsolutePath]

  public init(group: MultiThreadedEventLoopGroup, config: ServerConfiguration) throws {
    self.group = group
    self.config = config
    self.swiftPathsByVersionString =
      try mapSwiftPathsByVersion(config.swiftCompilerFrontends)
  }

  // public func start() -> EventLoopFuture<DistributedBuildServer> {
  // }
}

private func mapSwiftPathsByVersion(_ swiftPaths: [AbsolutePath]) throws
  -> [String: AbsolutePath] {
    var map: [String: AbsolutePath] = [:]
    for swiftPath in swiftPaths {
      let versionStr = try Process.checkNonZeroExit(args: swiftPath.pathString,
                                                    "--version")
      if map[versionStr] == nil {
        map[versionStr] = swiftPath
      }
    }
    return map
}
