//===------ DependencyAnalysis.swift - Compute internal dependencies ------===//
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
import Foundation
@_implementationOnly import Yams

extension DistributedBuildInfo {
  struct DependencyMap {
    // If internalDependancies[i] = [m, n], it implies that:
    //   - sourceFiles[i] depends on sourceFiles[m] and sourceFiles[n]
    // If file A depends on file B, it means that:
    //   - When compiling file A as a primary file, file B must be included in
    //     the compilation as a secondary file
    //   - When performing incremental compilation, if file B has changed since
    //     the last build, file A must be recompiled even if it's unchanged
    let internalDependencies: [Set<SourceFileIndex>]

    // If any of these external dependency files has changed since the last
    // build, incremental compilation must be abandoned and all source files
    // must be compiled afresh.
    let externalDependencies: [AbsolutePath]
  }

  struct DependencyMapper {
    // A dependency kind and its identifying string(s)
    private enum DependencyItem: Hashable, Equatable {
      case topLevel(String)
      case nominal(String)
      case member(String, String)
      case dynamicLookup(String)
    }

    // A "depends-" entry in a swiftdeps file
    private struct DependsEntry {
      let dependantIndex: SourceFileIndex
      let dependencyItem: DependencyItem
      let isCascading: Bool
    }

    // Errors in the swiftdeps file
    enum SwiftDepsParseError: String, LocalizedError {
      case couldNotDecodeSwiftDepsFile
      case sectionNameNotString
      case nameEntryNotString
      case memberEntryNotStringPair
    }

    // Initialized
    private let sourceFilesCount: Int

    // Loaded from swiftdeps files
    private var providers: [DependencyItem: [SourceFileIndex]] = [:]
    private var dependsEntries: [DependsEntry] = []
    private var externalDependencies: Set<String> = []

    // To ensure all swiftdeps files are loaded
    private var isSwiftDepsFileLoaded: [Bool]

    init(sourceFilesCount: Int) {
      self.sourceFilesCount = sourceFilesCount
      self.isSwiftDepsFileLoaded = [Bool](repeating: false, count: sourceFilesCount)
    }

    mutating func loadSwiftDepsFile(path: VirtualPath, sourceFileIndex: SourceFileIndex) throws {
      let contents = try localFileSystem.readFileContents(path).cString
      try loadSwiftDepsFile(contents: contents, sourceFileIndex: sourceFileIndex)
    }

    mutating func loadSwiftDepsFile(contents: String, sourceFileIndex: SourceFileIndex) throws {
      precondition(sourceFileIndex >= 0 && sourceFileIndex < sourceFilesCount)
      guard let sections = try Parser(yaml: contents, resolver: .basic, encoding: .utf8)
        .singleRoot()?.mapping else {
          throw SwiftDepsParseError.couldNotDecodeSwiftDepsFile
      }

      func add(providerIndex: SourceFileIndex, for item: DependencyItem) {
        if providers[item] == nil {
          providers[item] = [providerIndex]
        } else {
          providers[item]!.append(providerIndex)
        }
      }

      func add(dependantIndex: SourceFileIndex, for item: DependencyItem, isCascading: Bool) {
        dependsEntries.append(
          DependsEntry(dependantIndex: dependantIndex, dependencyItem: item,
                     isCascading: isCascading)
        )
      }

      for (key, value) in sections {
        guard let k = key.scalar?.string else {
          throw SwiftDepsParseError.sectionNameNotString
        }
        switch k {
        case "provides-top-level":
          try Self.decodeNameSequence(value) { (name, isPrivate) in
            assert(!isPrivate)
            add(providerIndex: sourceFileIndex, for: .topLevel(name))
          }
        case "provides-nominal":
          try Self.decodeNameSequence(value) { (name, isPrivate) in
            assert(!isPrivate)
            add(providerIndex: sourceFileIndex, for: .nominal(name))
          }
        case "provides-member":
          try Self.decodeMemberSequence(value) { (name, member, isPrivate) in
            assert(!isPrivate)
            add(providerIndex: sourceFileIndex, for: .member(name, member))
          }
        case "provides-dynamic-lookup":
          try Self.decodeNameSequence(value) { (name, isPrivate) in
            assert(!isPrivate)
            add(providerIndex: sourceFileIndex, for: .dynamicLookup(name))
          }
        case "depends-top-level":
          try Self.decodeNameSequence(value) { (name, isPrivate) in
            add(dependantIndex: sourceFileIndex, for: .topLevel(name),
                isCascading: !isPrivate)
          }
        case "depends-nominal":
          try Self.decodeNameSequence(value) { (name, isPrivate) in
            add(dependantIndex: sourceFileIndex, for: .nominal(name),
                isCascading: !isPrivate)
          }
        case "depends-member":
          try Self.decodeMemberSequence(value) { (name, member, isPrivate) in
            add(dependantIndex: sourceFileIndex, for: .member(name, member),
                isCascading: !isPrivate)
          }
        case "depends-dynamic-lookup":
          try Self.decodeNameSequence(value) { (name, isPrivate) in
            add(dependantIndex: sourceFileIndex, for: .dynamicLookup(name),
                isCascading: !isPrivate)
          }
        case "depends-external":
          try Self.decodeNameSequence(value) { (name, isPrivate) in
            assert(!isPrivate)
            externalDependencies.insert(name)
          }
          break
        case "interface-hash":
          // No need to read the interface hash for distributed building
          break
        default:
          break
        }
      }
      isSwiftDepsFileLoaded[sourceFileIndex] = true
    }

    private static func decodeNameSequence(
      _ node: Yams.Node,
      callback: (_ name: String, _ isTaggedPrivate: Bool) -> Void) throws {
      for element in node.array() {
        let isTaggedPrivate = (element.tag.description == "!private")
        guard let name = element.scalar?.string else {
          throw SwiftDepsParseError.nameEntryNotString
        }
        callback(name, isTaggedPrivate)
      }
    }

    private static func decodeMemberSequence(
      _ node: Yams.Node,
      callback: (_ name: String, _ member: String, _ isTaggedPrivate: Bool) -> Void) throws {
      for element in node.array() {
        let isTaggedPrivate = (element.tag.description == "!private")
        let pair = element.array()
        guard pair.count == 2,
          let name = pair.first!.scalar?.string,
          let member = pair.last!.scalar?.string else {
            throw SwiftDepsParseError.memberEntryNotStringPair
        }
        callback(name, member, isTaggedPrivate)
      }
    }

    func computeDependencyMap() -> DependencyMap {
      // This function should be called after loading all swiftdeps files
      precondition(isSwiftDepsFileLoaded.allSatisfy { $0 == true })

      // Set of direct non-cascading dependencies of a source file
      var nonCascadingDependencies = [Set<SourceFileIndex>](repeating: [], count: sourceFilesCount)

      // Set of direct cascading dependencies of a source file
      var directCascadingDependencies = [Set<SourceFileIndex>](repeating: [], count: sourceFilesCount)

      // Find all cascading dependencies (direct and transitive) of a source file
      func getAllCascadingDependencies(
        from: SourceFileIndex) -> Set<SourceFileIndex> {
        var visited: Set<Int> = []
        return getAllCascadingDependencies(from: from, visited: &visited)
      }

      func getAllCascadingDependencies(
        from: SourceFileIndex,
        visited: inout Set<SourceFileIndex>) -> Set<SourceFileIndex> {

        // Handle cyclic dependencies
        if visited.contains(from) {
          return []
        }
        visited.insert(from)

        // Start with direct cascading dependencies
        let directDependencies = directCascadingDependencies[from]
        var allDependencies = directDependencies

        // Add transitive cascading dependencies recursively
        directDependencies.forEach {
          let transitiveDependencies = getAllCascadingDependencies(from: $0, visited: &visited)
          transitiveDependencies.forEach { transitiveDependency in
            if transitiveDependency != from {
              allDependencies.insert(transitiveDependency)
            }
          }
        }

        // Return union of direct and transitive dependencies
        return allDependencies
      }

      // Form sets of cascading and non-cascading direct dependencies
      for dependsEntry in dependsEntries {
        let dependantIndex = dependsEntry.dependantIndex
        providers[dependsEntry.dependencyItem]?.forEach { providerIndex in
          if providerIndex != dependantIndex {
            if dependsEntry.isCascading {
              directCascadingDependencies[dependantIndex].insert(providerIndex)
            } else {
              nonCascadingDependencies[dependantIndex].insert(providerIndex)
            }
          }
        }
      }

      // Handle transitive dependencies
      // Let's say 'X -> Y' implies X directly depends on Y.
      // If A -> B, B -> C, C -> D, then transitive dependencies are found as:
      //   - if B -> C is cascading, then A depends on C
      //   - if both B -> C and C -> D are cascading, then A depends on D
      var dependsOn = [Set<Int>](repeating: [], count: sourceFilesCount)
      for i in (0 ..< sourceFilesCount) {
        let directNonCascading = nonCascadingDependencies[i]
        let directCascading = directCascadingDependencies[i]
        let allDirect = directNonCascading.union(directCascading)
        var allDependencies = allDirect
        allDirect.forEach { directDependency in
          let transitive = getAllCascadingDependencies(from: directDependency)
          transitive.forEach { transitiveDependency in
            if transitiveDependency != i {
              allDependencies.insert(transitiveDependency)
            }
          }
        }
        dependsOn[i] = allDependencies
      }

      return DependencyMap(
        internalDependencies: dependsOn,
        externalDependencies: externalDependencies.map { AbsolutePath($0) }
      )
    }
  }
}
