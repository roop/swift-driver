//===------------- ClientConfiguration.swift - Client config --------------===//
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

// The client configuration file is a YAML file that contains information
// on which servers the client should contact.
//
// Here's an example of the file contents:
//
//   servers:
//     - { host: "127.0.0.1", port: 8000 }
//     - { host: "::1", port: 8002 }
//     - { host: "localhost", port: 8003, timeout_seconds: 25 }
//   default_timeout_seconds: 5

public struct ClientConfiguration {

  public struct ServerData {
    public let host: String
    public let port: UInt
    public let timeoutSeconds: UInt

    public init(host: String, port: UInt, timeoutSeconds: UInt) {
      self.host = host
      self.port = port
      self.timeoutSeconds = timeoutSeconds
    }
  }

  public let servers: [ServerData]

  public init(servers: [ServerData]) {
    self.servers = servers
  }
}

extension ClientConfiguration {

  public enum ConfigFileError: Error {
    case distributedBuildClientConfigFileNotFound
    case couldNotDecodeConfigFile
    case keyNotString
    case unknownConfigKey(String)
    case serverDataNotDictionary
    case serverKeyNotString
    case hostValueNotString
    case portValueInvalid
    case timeoutSecondsValueInvalid
    case unknownServerKeyInConfig(String)
    case hostValueNotFound
    case portValueNotFound
  }

  public static func fromFile(_ path: AbsolutePath) throws
    -> ClientConfiguration {
    guard localFileSystem.isFile(path) else {
      throw ConfigFileError.distributedBuildClientConfigFileNotFound
    }
    let contents = try localFileSystem.readFileContents(path).cString
    return try Self.fromContents(contents)
  }

  public static func fromContents(_ str: String) throws
    -> ClientConfiguration {
      guard let topLevelDict = try Parser(yaml: str, resolver: .basic, encoding: .utf8)
        .singleRoot()?.mapping else {
          throw ConfigFileError.couldNotDecodeConfigFile
      }

      var serverEntries: [(String, UInt, UInt?)] = []
      var defaultTimeoutSeconds: UInt = 5 /* Implicit default */

      for (key, value) in topLevelDict {
        guard let k = key.scalar?.string else {
          throw ConfigFileError.keyNotString
        }
        switch k {
        case "servers":
          serverEntries = try decodeServerDataSequence(value)
        case "default_timeout_seconds":
          defaultTimeoutSeconds = try decodeDefaultTimeout(value)
        default:
          throw ConfigFileError.unknownConfigKey(k)
        }
      }

      let serverData = serverEntries.map {
        ClientConfiguration.ServerData(
          host: $0.0,
          port: $0.1,
          timeoutSeconds: $0.2 ?? defaultTimeoutSeconds
        )
      }

      return ClientConfiguration(servers: serverData)
  }

  private static func decodeServerDataSequence(_ node: Yams.Node) throws
    -> [(String, UInt, UInt?)] {
      var servers: [(String, UInt, UInt?)] = []
      for element in node.array() {
        guard let serverData = element.mapping else {
          throw ConfigFileError.serverDataNotDictionary
        }
        var host: String? = nil
        var port: UInt? = nil
        var timeoutSeconds: UInt? = nil
        for (key, value) in serverData {
          guard let k = key.scalar?.string else {
            throw ConfigFileError.serverKeyNotString
          }
          switch k {
          case "host":
            guard let hostString = value.scalar?.string else {
              throw ConfigFileError.hostValueNotString
            }
            host = hostString
          case "port":
            guard let scalar = value.scalar,
              let integer = UInt.construct(from: scalar) else {
              throw ConfigFileError.portValueInvalid
            }
            port = integer
          case "timeout_seconds":
            guard let scalar = value.scalar,
              let integer = UInt.construct(from: scalar) else {
              throw ConfigFileError.timeoutSecondsValueInvalid
            }
            timeoutSeconds = integer
          default:
            throw ConfigFileError.unknownServerKeyInConfig(k)
          }
        }
        guard let h = host else {
          throw ConfigFileError.hostValueNotFound
        }
        guard let p = port else {
          throw ConfigFileError.portValueNotFound
        }
        servers.append((h, p, timeoutSeconds))
      }
      return servers
  }

  private static func decodeDefaultTimeout(_ node: Yams.Node) throws
    -> UInt {
      guard let scalar = node.scalar,
        let integer = UInt.construct(from: scalar) else {
        throw ConfigFileError.timeoutSecondsValueInvalid
      }
      return integer
  }
}
