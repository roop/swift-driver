import XCTest

import FlockClientTests
import FlockServerTests
import SwiftDriverTests
import SwiftOptionsTests

var tests = [XCTestCaseEntry]()
tests += FlockClientTests.__allTests()
tests += FlockServerTests.__allTests()
tests += SwiftDriverTests.__allTests()
tests += SwiftOptionsTests.__allTests()

XCTMain(tests)
