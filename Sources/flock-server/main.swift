//===------------- main.swift - Flock Server Main Entrypoint --------------===//
//
// Copyright (c) 2020 Roopesh Chander <http://roopc.net/>
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import FlockServer

import TSCBasic
import TSCLibc

guard let cwd = localFileSystem.currentWorkingDirectory else {
  fatalError("Can't get current working directory")
}

let configFile = AbsolutePath("flock_server_config.yaml", relativeTo: cwd)
guard localFileSystem.isFile(configFile) else {
  fatalError("Server config '\(configFile.pathString)' not found")
}

do {
  let config = try ServerConfiguration.fromFile(configFile)
  let server = try DistributedBuildServer(serverConfiguration: config)
  print(server.swiftPathsByVersionString)
  print(config.sdks)
} catch {
  print("error: \(error)")
  exit(EXIT_FAILURE)
}

