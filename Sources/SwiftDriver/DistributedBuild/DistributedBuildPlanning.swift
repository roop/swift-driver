//===-- DistributedBuildPlanning.swift - Planning for distributed builds --===//
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
import SwiftOptions

/// Planning for distributed builds
extension Driver {
  public var isDistributedBuildEnabled: Bool {
    if distributedBuildInfo == nil {
      return false
    }

    // Only compilation can be distributed as of now, not linking
    if !inputFiles.contains(where: { $0.type.isPartOfSwiftCompilation }) {
      return false
    }

    // We can do distributed builds only when using primary inputs
    if !compilerMode.usesPrimaryFileInputs {
      diagnosticEngine.emit(.warning_ignoring_distributed_option(
        because: "it is not compatible with \(compilerMode)"))
      return false
    }

    // We can do distributed builds only when there's an output file map
    if outputFileMap == nil {
      diagnosticEngine.emit(.warning_ignoring_distributed_option(
        because: "it requires an output file map"))
      return false
    }

    return true
  }

  private typealias RemoteCompilationInfo = DistributedBuildInfo.RemoteCompilationInfo
  private typealias SwiftDepsMap = DistributedBuildInfo.SwiftDepsMap

  public mutating func planDistributedBuild() throws -> DistributedBuildInfo.BuildPlan {
    precondition(compilerMode.usesPrimaryFileInputs)
    precondition(!forceEmitModuleInSingleInvocation)
    guard let distributedBuildInfo = distributedBuildInfo else { fatalError() }

    // Info needed to create the build plan
    var sourceFiles: [RelativePath] = []
    var preCompilationJobs: [Job] = []
    var postCompilationJobs: [Job] = []
    var swiftDepsMap: [RelativePath: TypedVirtualPath] = [:]
    var compilationOptions: [String]
    var remoteCompilationOutputPaths: [RelativePath: [TypedVirtualPath]] = [:]

    // Keep track of the various outputs we care about from the jobs we build.
    var linkerInputs: [TypedVirtualPath] = []
    var moduleInputs: [TypedVirtualPath] = []
    func addCompilerOutputsAsInputs(_ jobOutputs: [TypedVirtualPath]) {
      for jobOutput in jobOutputs {
        switch jobOutput.type {
        case .object, .autolink:
          linkerInputs.append(jobOutput)

        case .swiftModule:
          moduleInputs.append(jobOutput)

        default:
          break
        }
      }
    }

    let partitions: BatchPartitions?

    switch compilerMode {
    case .batchCompile(let batchInfo):
      partitions = batchPartitions(batchInfo)

    case .standardCompile:
      partitions = nil

    case .immediate, .repl, .compilePCM, .singleCompile:
      fatalError("compiler mode \(compilerMode) cannot be distributed")
    }

    for input in inputFiles {
      switch input.type {
      case .swift, .sil, .sib:
        // Generate a compile job for primary inputs here.
        precondition(compilerMode.usesPrimaryFileInputs)

        if let remotePath = distributedBuildInfo.remoteInputPath(localPath: input.file) {
          sourceFiles.append(remotePath)
          let remoteOutputs = remoteCompilationOutputs(for: input)
          remoteCompilationOutputPaths[remotePath] = remoteOutputs
          addCompilerOutputsAsInputs(remoteOutputs)
        } else {
          diagnosticEngine.emit(
            .error_source_file_outside_of_base_dir(sourceFile: input))
        }

        var primaryInputs: [TypedVirtualPath]
        if let partitions = partitions, let partitionIdx = partitions.assignment[input] {
          // We have a partitioning for batch mode. If this input file isn't the first
          // file in the partition, skip it: it's been accounted for already.
          if partitions.partitions[partitionIdx].first! != input {
            continue
          }

          primaryInputs = partitions.partitions[partitionIdx]
        } else {
          primaryInputs = [input]
        }

        let job = try emitSwiftDepsJob(primaryInputs: primaryInputs, outputType: compilerOutputType, swiftDepsMap: &swiftDepsMap)
        preCompilationJobs.append(job)

      case .object, .autolink:
        if linkerOutputType != nil {
          linkerInputs.append(input)
        } else {
          diagnosticEngine.emit(.error_unexpected_input_file(input.file))
        }

      case .swiftModule, .swiftDocumentation:
        if moduleOutput != nil && linkerOutputType == nil {
          // When generating a .swiftmodule as a top-level output (as opposed
          // to, for example, linking an image), treat .swiftmodule files as
          // inputs to a MergeModule action.
          moduleInputs.append(input)
        } else if linkerOutputType != nil {
          // Otherwise, if linking, pass .swiftmodule files as inputs to the
          // linker, so that their debug info is available.
          linkerInputs.append(input)
        } else {
          diagnosticEngine.emit(.error_unexpected_input_file(input.file))
        }

      default:
        diagnosticEngine.emit(.error_unexpected_input_file(input.file))
      }
    }

    // Plan the merge-module job, if there are module inputs.
    if moduleOutput != nil && !moduleInputs.isEmpty && compilerMode.usesPrimaryFileInputs {
      postCompilationJobs.append(try mergeModuleJob(inputs: moduleInputs))
    }

    // If we need to autolink-extract, do so.
    let autolinkInputs = linkerInputs.filter { $0.type == .object }
    if let autolinkExtractJob = try autolinkExtractJob(inputs: autolinkInputs) {
      linkerInputs.append(contentsOf: autolinkExtractJob.outputs)
      postCompilationJobs.append(autolinkExtractJob)
    }

    // If we should link, do so.
    var link: Job?
    if linkerOutputType != nil && !linkerInputs.isEmpty {
      link = try linkJob(inputs: linkerInputs)
      postCompilationJobs.append(link!)
    }

    // If we should generate a dSYM, do so.
    if let linkJob = link, targetTriple.isDarwin, debugInfoLevel != nil {
      let dsymJob = try generateDSYMJob(inputs: linkJob.outputs)
      postCompilationJobs.append(dsymJob)
      if shouldVerifyDebugInfo {
        postCompilationJobs.append(try verifyDebugInfoJob(inputs: dsymJob.outputs))
      }
    }

    let remoteCompilationInfo = RemoteCompilationInfo(outputs: remoteCompilationOutputPaths)

    return DistributedBuildInfo.BuildPlan(
      preCompilationJobs: preCompilationJobs,
      sourceFiles: sourceFiles.sorted { $0.pathString < $1.pathString },
      swiftDepsMap: swiftDepsMap,
      remoteCompilationInfo: remoteCompilationInfo,
      postCompilationJobs: postCompilationJobs)
  }

  private func remoteCompilationOutputs(for input: TypedVirtualPath) -> [TypedVirtualPath] {
    precondition(compilerMode.usesPrimaryFileInputs)
    guard let outputFileMap = outputFileMap else { fatalError() }

    guard input.type.isPartOfSwiftCompilation else { return [] }
    guard let compilerOutputType = compilerOutputType else { return [] }

    let outputTypes: [FileType] = [compilerOutputType,
                                   .swiftModule,
                                   .swiftDocumentation]

    let outputs: [TypedVirtualPath] = outputTypes.compactMap { outputType in
      if let path = outputFileMap.existingOutput(inputFile: input.file, outputType: outputType) {
        return TypedVirtualPath(file: path, type: outputType)
      }
      return nil
    }

    return outputs
  }

  /// Form a job that executes the Swift frontend to emit swiftdeps files
  private mutating func emitSwiftDepsJob(primaryInputs: [TypedVirtualPath],
                                 outputType: FileType?,
                                 swiftDepsMap: inout SwiftDepsMap) throws -> Job {
    precondition(compilerMode.usesPrimaryFileInputs)
    precondition(!forceEmitModuleInSingleInvocation)

    var commandLine: [Job.ArgTemplate] = swiftCompilerPrefixArgs.map { Job.ArgTemplate.flag($0) }

    commandLine.appendFlag("-frontend")
    commandLine.appendFlag(Option.typecheck)

    // Add input files
    let swiftInputFiles = inputFiles.filter { $0.type.isPartOfSwiftCompilation }
    for input in swiftInputFiles {
      if primaryInputs.contains(input) {
        commandLine.appendFlag(.primaryFile)
      }
      commandLine.append(.path(input.file))
    }

    // Add args for .d and .swiftdeps outputs
    let swiftDepsOutputPaths = addDependencyOutputArguments(
      primaryInputs: primaryInputs, commandLine: &commandLine,
      swiftDepsMap: &swiftDepsMap)

    if parsedOptions.hasArgument(.parseStdlib) {
      commandLine.appendFlag(.disableObjcAttrRequiresFoundationModule)
    }

    try addCommonFrontendOptions(commandLine: &commandLine)
    // FIXME: MSVC runtime flags

    if parsedOptions.hasArgument(.parseAsLibrary, .emitLibrary) {
      commandLine.appendFlag(.parseAsLibrary)
    }

    try commandLine.appendLast(.parseSil, from: &parsedOptions)

    return Job(
      kind: .compile,
      tool: .absolute(try toolchain.getToolPath(.swiftCompiler)),
      commandLine: commandLine,
      displayInputs: primaryInputs,
      inputs: swiftInputFiles,
      outputs: swiftDepsOutputPaths,
      supportsResponseFiles: true
    )
  }

  private func addDependencyOutputArguments(
    primaryInputs: [TypedVirtualPath],
    commandLine: inout [Job.ArgTemplate],
    swiftDepsMap: inout SwiftDepsMap) -> [TypedVirtualPath] {

    precondition(compilerMode.usesPrimaryFileInputs)
    guard let outputFileMap = outputFileMap else { fatalError() }
    guard let distributedBuildInfo = distributedBuildInfo else { fatalError() }

    // If the outputFileMap contains any .d entry, dump .d files for all primary inputs,
    // else, don't dump any .d files
    var isOutputFileMapContainsMakeCompatibleDependencies = false
    for input in primaryInputs {
      if outputFileMap.existingOutput(inputFile: input.file, outputType: .dependencies) != nil {
        isOutputFileMapContainsMakeCompatibleDependencies = true
        break
      }
    }

    var swiftDepsOutputPaths: [TypedVirtualPath] = []

    func addOutputOfType(_ outputType: FileType, input: TypedVirtualPath, flag: Option) {
      precondition(flag.kind == .separate)
      let outputPath = outputFileMap.getOutput(inputFile: input.file, outputType: outputType)
      commandLine.appendFlag(flag)
      commandLine.appendPath(outputPath)
      if outputType == .swiftDeps {
        let swiftDepsOutputPath = TypedVirtualPath(file: outputPath, type: outputType)
        if let remotePath = distributedBuildInfo.remoteInputPath(localPath: input.file) {
          assert(swiftDepsMap[remotePath] == nil)
          swiftDepsMap[remotePath] = swiftDepsOutputPath
          swiftDepsOutputPaths.append(swiftDepsOutputPath)
        }
      }
    }

    for input in primaryInputs {
      addOutputOfType(.swiftDeps, input: input, flag: .emitReferenceDependenciesPath)
      if isOutputFileMapContainsMakeCompatibleDependencies {
        addOutputOfType(.dependencies, input: input, flag: .emitDependenciesPath)
      }
    }

    return swiftDepsOutputPaths
  }
}

extension Diagnostic.Message {
  static func warning_ignoring_distributed_option(
    because why: String) -> Diagnostic.Message {
    .warning("ignoring '-distributed', because \(why).\n")
  }

  static func error_source_file_outside_of_base_dir(
    sourceFile: TypedVirtualPath) -> Diagnostic.Message {
    .error("source file \(sourceFile.file) outside of '-distributed-build-base-dir'")
  }
}
