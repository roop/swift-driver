//===------- DistributedBuildInfo.swift - Info on distributed builds ------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Copyright (c) 2020 Roopesh Chander <http://roopc.net/>
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import TSCBasic
import FlockClient

public struct DistributedBuildInfo {
  // Maps a source file to its local swiftDeps file
  typealias SwiftDepsMap = [RelativePath: TypedVirtualPath]

  // An index into BuildPlan.sourceFiles; can uniquely identify a source file
  typealias SourceFileIndex = Int

  public struct BuildPlan {
    // Jobs to be run locally before requesting remote compilations
    let preCompilationJobs: [Job]

    // Files to be compiled, relative to baseDir
    let sourceFiles: [RelativePath]

    // Maps a source file to its local swiftDeps file
    let swiftDepsMap: SwiftDepsMap

    // Info that we need for remote compilation
    let remoteCompilationInfo: RemoteCompilationInfo

    // For an input source file, the local paths for outputs generated remotely
    let outputPaths: [RelativePath: RemoteCompilationOutputPathMap]

    // Jobs to be run locally after distributed compilation succeeds
    let postCompilationJobs: [Job]
  }

  // The base directory for all input source files
  let baseDir: AbsolutePath

  init(distributedBuildBaseDir: AbsolutePath) {
    baseDir = distributedBuildBaseDir
  }

  func remoteInputPath(localPath: AbsolutePath) -> RelativePath? {
    let relativePath = localPath.relative(to: baseDir)
    if relativePath.components.first == ".." {
      // The base dir is not an ancestor of this local path
      return nil
    }
    return relativePath
  }

  func remoteInputPath(localPath: VirtualPath) -> RelativePath? {
    switch localPath {
    case .absolute(let absolutePath):
      return remoteInputPath(localPath: absolutePath)
    case .relative(let relativePath):
      guard let cwd = localFileSystem.currentWorkingDirectory else { return nil }
      return remoteInputPath(localPath: AbsolutePath(cwd, relativePath))
    default:
      return nil
    }
  }
}
