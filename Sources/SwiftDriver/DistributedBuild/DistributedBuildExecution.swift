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

extension Driver {
  private typealias DependencyMapper = DistributedBuildInfo.DependencyMapper
  private typealias DependencyMap = DistributedBuildInfo.DependencyMap
  private typealias BuildPlan = DistributedBuildInfo.BuildPlan

  public mutating func executeDistributedBuildPlan(
    buildPlan: DistributedBuildInfo.BuildPlan, processSet: ProcessSet) throws {
    let resolver = try ArgsResolver()
    try run(jobs: buildPlan.preCompilationJobs, resolver: resolver, processSet: processSet)

    if diagnosticEngine.hasErrors { return }

    let dependencyMap = try Self.computeDependencyMapForDistributedBuild(buildPlan: buildPlan)
    Self.printDependencyStats(buildPlan: buildPlan, dependencyMap: dependencyMap)
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
