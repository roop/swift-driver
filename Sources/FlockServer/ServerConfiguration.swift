//===------------- ServerConfiguration.swift - Server config --------------===//
//
// Copyright (c) 2020 Roopesh Chander <http://roopc.net/>
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import TSCBasic
import Yams

// The server configuration file is a YAML file.
//
// Here's an example of the file contents:
//
//   swift_compiler_frontends:
//     - /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift
//   sdks:
//     "MacOSX10.15" : "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk"
//     "MacOSX10.14" : "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.14.sdk"
//   port: 8000
//   number_of_parallel_compilations: 1

public struct ServerConfiguration {
  public let swiftCompilerFrontends: [AbsolutePath]
  public let sdks: [String: AbsolutePath]
  public let port: UInt
  public let numberOfParallelCompilations: UInt?

  public init(swiftCompilerFrontends: [AbsolutePath],
              sdks: [String: AbsolutePath],
              port: UInt,
              numberOfParallelCompilations: UInt? = nil) {
    self.swiftCompilerFrontends = swiftCompilerFrontends
    self.sdks = sdks
    self.port = port
    self.numberOfParallelCompilations = numberOfParallelCompilations
  }
}

extension ServerConfiguration {

  public enum ConfigFileError: Error {
    case distributedBuildServerConfigFileNotFound
    case couldNotDecodeConfigFile
    case keyNotString
    case unknownConfigKey(String)
    case swiftFrontendItemNotAbsolutePath
    case sdkDataNotDictionary
    case sdkDataKeyNotString
    case sdkDataValueNotAbsolutePath
    case portValueNotFound
    case portValueInvalid
    case numberOfParallelCompilationsValueInvalid
  }

  public static func fromFile(_ path: AbsolutePath) throws
    -> ServerConfiguration {
      guard localFileSystem.isFile(path) else {
        throw ConfigFileError.distributedBuildServerConfigFileNotFound
      }
      let contents = try localFileSystem.readFileContents(path).cString
      return try Self.fromContents(contents)
  }

  public static func fromContents(_ str: String) throws
    -> ServerConfiguration {
      guard let topLevelDict = try Parser(yaml: str, resolver: .basic, encoding: .utf8)
        .singleRoot()?.mapping else {
          throw ConfigFileError.couldNotDecodeConfigFile
      }

      var swiftFrontendPaths: [AbsolutePath] = []
      var sdkPaths: [String: AbsolutePath] = [:]
      var port: UInt? = nil
      var numberOfParallelCompilations: UInt? = nil

      for (key, value) in topLevelDict {
        guard let k = key.scalar?.string else {
          throw ConfigFileError.keyNotString
        }
        switch k {
        case "swift_compiler_frontends":
          swiftFrontendPaths = try decodeSwiftFrontendPaths(value)
        case "sdks":
          sdkPaths = try decodeSDKPaths(value)
        case "port":
          if let uintValue = decodeUIntValue(value) {
            port = uintValue
          } else {
            throw ConfigFileError.portValueInvalid
          }
        case "number_of_parallel_compilations":
          if let uintValue = decodeUIntValue(value) {
            numberOfParallelCompilations = uintValue
          } else {
            throw ConfigFileError.numberOfParallelCompilationsValueInvalid
          }
        default:
          throw ConfigFileError.unknownConfigKey(k)
        }
      }

      guard let p = port else {
        throw ConfigFileError.portValueNotFound
      }

      return ServerConfiguration(
        swiftCompilerFrontends: swiftFrontendPaths,
        sdks: sdkPaths,
        port: p,
        numberOfParallelCompilations: numberOfParallelCompilations)
  }

  private static func decodeSwiftFrontendPaths(_ node: Yams.Node) throws
    -> [AbsolutePath] {
      var absPaths: [AbsolutePath] = []
      for element in node.array() {
        guard let pathStr = element.scalar?.string,
          let absPath = try? AbsolutePath(validating: pathStr) else {
            throw ConfigFileError.swiftFrontendItemNotAbsolutePath
        }
        absPaths.append(absPath)
      }
      return absPaths
  }

  private static func decodeSDKPaths(_ node: Yams.Node) throws
    -> [String: AbsolutePath] {
      var absPathMap: [String: AbsolutePath] = [:]
      guard let sdkData = node.mapping else {
        throw ConfigFileError.sdkDataNotDictionary
      }
      for (key, value) in sdkData {
        guard let k = key.scalar?.string else {
          throw ConfigFileError.sdkDataKeyNotString
        }
        guard let pathStr = value.scalar?.string,
          let absPath = try? AbsolutePath(validating: pathStr) else {
            throw ConfigFileError.sdkDataValueNotAbsolutePath
        }
        absPathMap[k] = absPath
      }
      return absPathMap
  }

  private static func decodeUIntValue(_ node: Yams.Node)
    -> UInt? {
      if let scalar = node.scalar {
        return UInt.construct(from: scalar)
      }
      return nil
  }
}
