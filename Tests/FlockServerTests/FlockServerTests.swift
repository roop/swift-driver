//===------------ FlockServerTests.swift - Flock Server Tests -------------===//
//
// Copyright (c) 2020 Roopesh Chander <http://roopc.net/>
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import FlockServer
import TSCBasic
import XCTest

final class FlockServerTests: XCTestCase {

  func testServerConfigParsing() throws {
    let str = """
      # Flock server config
      swift_compiler_frontends:
        - "/swift1"
        - "/swift2"
        - "/swift3"
      sdks:
        "MacOSX10.5" : "/path/to/macosx/10.5/sdk"
        "MacOSX10.4" : "/path/to/macosx/10.4/sdk"
      port: 8000
      number_of_parallel_compilations: 1
      """

    let config = try ServerConfiguration.fromContents(str)
    XCTAssertEqual(
      config.swiftCompilerFrontends,
      ["/swift1", "/swift2", "/swift3"].map { AbsolutePath($0) })
    XCTAssertEqual(
      config.sdks,
      [
        "MacOSX10.5" : AbsolutePath("/path/to/macosx/10.5/sdk"),
        "MacOSX10.4" : AbsolutePath("/path/to/macosx/10.4/sdk")
      ])
    XCTAssertEqual(config.port, 8000)
    XCTAssertEqual(config.numberOfParallelCompilations, 1)
  }
}
