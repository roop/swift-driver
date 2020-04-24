//===--- DistributedBuildExecution.swift - Executing distributed builds ---===//
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

extension Driver {
  private typealias DependencyMapper = DistributedBuildInfo.DependencyMapper
  private typealias DependencyMap = DistributedBuildInfo.DependencyMap
  private typealias BuildPlan = DistributedBuildInfo.BuildPlan

  public mutating func executeDistributedBuildPlan(
    buildPlan: DistributedBuildInfo.BuildPlan, processSet: ProcessSet) throws {
    guard let distributedBuildInfo = distributedBuildInfo else { fatalError() }
    let resolver = try ArgsResolver()
    try run(jobs: buildPlan.preCompilationJobs, resolver: resolver, processSet: processSet)

    if diagnosticEngine.hasErrors { return }

    let dependencyMap = try Self.computeDependencyMapForDistributedBuild(buildPlan: buildPlan)

    #if !USE_MOCK_DISTRIBUTED_BUILD

    // Distributed build

    // We don't have incremental compilation yet, so for now,
    // we'll say all source files need to be compiled
    let allSourceFileIndices = Set<Int>(0 ..< buildPlan.sourceFiles.count)

    let compilerInputs = RemoteCompilationInputs(
      baseDir: distributedBuildInfo.baseDir,
      sourceFiles: buildPlan.sourceFiles,
      primarySourceFileIndices: allSourceFileIndices,
      secondarySourceFileIndices: dependencyMap.internalDependencies)

    _ = DistributedBuildClient(
      inputs: compilerInputs,
      outputPaths: buildPlan.outputPaths,
      compilationInfo: buildPlan.remoteCompilationInfo,
      configuration: distributedBuildInfo.clientConfig
    )

    #else

    // Mock distributed build

    print("Using mock distributed build")
    let jobs = try planMockDistributedCompile(
      baseDir: distributedBuildInfo.baseDir,
      sourceFiles: buildPlan.sourceFiles,
      dependencyMap: dependencyMap,
      outputPaths: buildPlan.outputPaths)
    try run(jobs: jobs, resolver: resolver, processSet: processSet)
    try run(jobs: buildPlan.postCompilationJobs, resolver: resolver, processSet: processSet)

    #endif // USE_MOCK_DISTRIBUTED_BUILD

  }

  private static func computeDependencyMapForDistributedBuild(
    buildPlan: BuildPlan) throws -> DependencyMap {
    var dependencyMapper = DependencyMapper(sourceFilesCount: buildPlan.sourceFiles.count)
    for (i, sourceFile) in buildPlan.sourceFiles.enumerated() {
      guard let swiftDepsPath = buildPlan.swiftDepsMap[sourceFile] else { fatalError() }
      assert(swiftDepsPath.type == .swiftDeps)
      try dependencyMapper.loadSwiftDepsFile(path: swiftDepsPath.file, sourceFileIndex: i)
    }

    return dependencyMapper.computeDependencyMap()
  }

  private static func printDependencyStats(buildPlan: BuildPlan, dependencyMap: DependencyMap) {
    let total = buildPlan.sourceFiles.count
    print("Total number of files: \(total)")
    print("Number of depedencies of:")
    var totalDependenciesCount = 0
    for (i, sourceFile) in buildPlan.sourceFiles.enumerated() {
      let dependenciesCount = dependencyMap.internalDependencies[i].count
      print("    \(sourceFile): \(dependenciesCount) (\((dependenciesCount*100)/total) %)")
      totalDependenciesCount += dependenciesCount
    }
    print("Average: \((totalDependenciesCount*100)/(total*total)) %")
  }
}
