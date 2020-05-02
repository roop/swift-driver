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

public class DistributedBuildServer {
  public var swiftPathsByVersionString: [String: AbsolutePath]

  public init(serverConfiguration config: ServerConfiguration) throws {
    self.swiftPathsByVersionString =
      try mapSwiftPathsByVersion(config.swiftCompilerFrontends)
  }
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
