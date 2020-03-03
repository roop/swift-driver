//===-- DistributedBuildPlanning.swift - Planning for distributed builds --===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Copyright (c) 2020 Roopesh Chander <http://roopc.net/>
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import TSCBasic

/// Planning for distributed builds
extension Driver {
  public struct DistributedBuildPlan {
  }

  public var isDistributedBuildEnabled: Bool {
    return (distributedBuildInfo != nil)
  }

  public func planDistributedBuild() throws -> DistributedBuildPlan {
    precondition(distributedBuildInfo != nil)
    return DistributedBuildPlan()
  }
}

extension Driver {
  public func executeDistributedBuildPlan(buildPlan: DistributedBuildPlan, processSet: ProcessSet) throws {
  }
}
