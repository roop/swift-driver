//===------------ FlockClientTests.swift - Flock Client Tests -------------===//
//
// Copyright (c) 2020 Roopesh Chander <http://roopc.net/>
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import FlockClient
import XCTest

final class FlockClientTests: XCTestCase {

  func testFlockClient() {
    let client = DistributedBuildClient()
    XCTAssertEqual(client.text, "Hello, World!")
  }
}
