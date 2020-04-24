//===--------------- ExtraOptions.swift - Swift Driver Extra Options ------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
extension Option {
  public static let driverPrintGraphviz: Option = Option("-driver-print-graphviz", .flag, attributes: [.helpHidden, .doesNotAffectIncrementalBuild], helpText: "Write the job graph as a graphviz file", group: .internalDebug)
  public static let distributed: Option = Option("-distributed", .flag, attributes: [.noInteractive, .doesNotAffectIncrementalBuild], helpText: "Enable distributed building")
  public static let distributedBuildBaseDirEQ: Option = Option("-distributed-build-base-dir=", .joined, alias: Option.distributedBuildBaseDir,  attributes: [.noInteractive, .argumentIsPath])
  public static let distributedBuildBaseDir: Option = Option("-distributed-build-base-dir", .separate, attributes: [.noInteractive, .argumentIsPath], metaVar: "<path>", helpText: "Base directory for all source files; used for distributed building (default: current dir)")
  public static let distributedBuildClientConfigEQ: Option = Option("-distributed-build-client-config=", .joined, alias: Option.distributedBuildClientConfig,  attributes: [.noInteractive, .argumentIsPath])
  public static let distributedBuildClientConfig: Option = Option("-distributed-build-client-config", .separate, attributes: [.noInteractive, .argumentIsPath], metaVar: "<path>", helpText: "Distributed build client configuration file (default: ./flock_client_config.yaml)")

  public static var extraOptions: [Option] {
    return [
      Option.driverPrintGraphviz,
      Option.distributed,
      Option.distributedBuildBaseDirEQ,
      Option.distributedBuildBaseDir,
      Option.distributedBuildClientConfigEQ,
      Option.distributedBuildClientConfig
    ]
  }
}
