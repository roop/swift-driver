//===--------------- main.swift - Swift Driver Main Entrypoint ------------===//
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
import SwiftDriver

import TSCLibc
import TSCBasic
import TSCUtility

var intHandler: InterruptHandler?
let diagnosticsEngine = DiagnosticsEngine(handlers: [Driver.stderrDiagnosticsHandler])

do {
  let processSet = ProcessSet()
  intHandler = try InterruptHandler {
    processSet.terminate()
  }

  let (mode, arguments) = try Driver.invocationRunMode(forArgs: CommandLine.arguments)

  if case .subcommand(let subcommand) = mode {
    // We are running as a subcommand, try to find the subcommand adjacent to the executable we are running as.
    // If we didn't find the tool there, let the OS search for it.
    let subcommandPath = Process.findExecutable(arguments[0])?.parentDirectory.appending(component: subcommand)
                         ?? Process.findExecutable(subcommand)

    if subcommandPath == nil || !localFileSystem.exists(subcommandPath!) {
      fatalError("cannot find subcommand executable '\(subcommand)'")
    }

    // Execute the subcommand.
    try exec(path: subcommandPath?.pathString ?? "", args: Array(arguments.dropFirst()))
  }

  var driver = try Driver(args: arguments, diagnosticsEngine: diagnosticsEngine)
  if driver.isDistributedBuildEnabled {
    let plan = try driver.planDistributedBuild()
    try driver.executeDistributedBuildPlan(buildPlan: plan, processSet: processSet)
  } else {
    let jobs = try driver.planBuild()
    let resolver = try ArgsResolver()
    try driver.run(jobs: jobs, resolver: resolver, processSet: processSet)
  }

  if driver.diagnosticEngine.hasErrors {
    exit(EXIT_FAILURE)
  }
} catch Diagnostics.fatalError {
  exit(EXIT_FAILURE)
} catch let diagnosticData as DiagnosticData {
  diagnosticsEngine.emit(.error(diagnosticData))
} catch {
  print("error: \(error)")
  exit(EXIT_FAILURE)
}
