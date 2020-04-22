//===------------ DistributedBuildClient.swift - Flock Client -------------===//
//
// Copyright (c) 2020 Roopesh Chander <http://roopc.net/>
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import TSCBasic

public struct RemoteCompilationInputs {
  // The local base dir for all source files
  let baseDir: AbsolutePath

  // Paths of all source files in the module, relative to baseDir
  let sourceFiles: [RelativePath]

  // The indices of source files that need to be compiled.
  // If i is part of the set, then sourceFiles[i] needs compilation.
  let primarySourceFileIndices: Set<Int>

  // For every source file, the set of indices of source files that
  // need to be passed to the frontend as secondary files.
  // If secondarySourceFileIndices[i] = [j, k], then when compiling
  // sourceFiles[i] as primary file, we should pass sourceFiles[j] and
  // sourceFiles[k] as secondary files.
  let secondarySourceFileIndices: [Set<Int>]

  public init(baseDir: AbsolutePath,
       sourceFiles: [RelativePath],
       primarySourceFileIndices: Set<Int>,
       secondarySourceFileIndices: [Set<Int>]) {
    self.baseDir = baseDir
    self.sourceFiles = sourceFiles
    self.primarySourceFileIndices = primarySourceFileIndices
    self.secondarySourceFileIndices = secondarySourceFileIndices
  }
}

// The types of outputs we get from remote compilation
public enum RemoteCompilationOutputType: Hashable, Equatable, CaseIterable {
  case object
  case swiftModule
  case swiftDocumentation
}

// For each type of output, where should that output be placed after
// remote compilation completes.
public typealias RemoteCompilationOutputPathMap = [RemoteCompilationOutputType: AbsolutePath]

public struct RemoteCompilationInfo {
  // Output of `swift --version`; Includes target information
  let compilerVersion: String

  // Identifies the SDK to use, like "MacOSX10.15"
  let sdkPlatformAndVersion: String

  // Arguments and options that should be passed to the frontend
  let frontendOptions: String

  public init(compilerVersion: String,
              sdkPlatformAndVersion: String,
              frontendOptions: String) {
    self.compilerVersion = compilerVersion
    self.sdkPlatformAndVersion = sdkPlatformAndVersion
    self.frontendOptions = frontendOptions
  }
}

public class DistributedBuildClient {
  // Inputs to the compilation
  let inputs: RemoteCompilationInputs

  // The outputs for a given input primary source file.
  let outputPaths: [RelativePath: RemoteCompilationOutputPathMap]

  // Compiler specification and options
  let compilationInfo: RemoteCompilationInfo

  // Server info and other configuration info
  let configuration: ClientConfiguration

  public init(inputs: RemoteCompilationInputs,
              outputPaths: [RelativePath: RemoteCompilationOutputPathMap],
              compilationInfo: RemoteCompilationInfo,
              configuration: ClientConfiguration) {
    self.inputs = inputs
    self.outputPaths = outputPaths
    self.compilationInfo = compilationInfo
    self.configuration = configuration
  }
}
