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
import XCTest

final class FlockServerTests: XCTestCase {

  func testFlockServer() {
    let server = DistributedBuildServer()
    XCTAssertEqual(server.text, "Hello, World!")
  }
}
