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

  func testClientConfigParsing() throws {
    let str = """
      # Flock client config
      servers:
        - { host: "127.0.0.1", port: 8000 }
        - { host: "::1", port: 8002 }
        - host: "localhost"
          port: 8003
          timeout_seconds: 25
      default_timeout_seconds: 60
      """

    let config = try ClientConfiguration.fromContents(str)

    XCTAssertEqual(config.servers[0].host, "127.0.0.1")
    XCTAssertEqual(config.servers[0].port, 8000)
    XCTAssertEqual(config.servers[0].timeoutSeconds, 60)

    XCTAssertEqual(config.servers[1].host, "::1")
    XCTAssertEqual(config.servers[1].port, 8002)
    XCTAssertEqual(config.servers[1].timeoutSeconds, 60)

    XCTAssertEqual(config.servers[2].host, "localhost")
    XCTAssertEqual(config.servers[2].port, 8003)
    XCTAssertEqual(config.servers[2].timeoutSeconds, 25)
  }
}
