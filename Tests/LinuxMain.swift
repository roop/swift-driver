import XCTest

import FlockClientTests
import SwiftDriverTests
import SwiftOptionsTests

var tests = [XCTestCaseEntry]()
tests += FlockClientTests.__allTests()
tests += SwiftDriverTests.__allTests()
tests += SwiftOptionsTests.__allTests()

XCTMain(tests)
