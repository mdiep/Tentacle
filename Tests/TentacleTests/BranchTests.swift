//
//  BranchTests.swift
//  Tentacle
//
//  Created by Romain Pouclet on 2017-02-15.
//  Copyright © 2017 Matt Diephouse. All rights reserved.
//

import XCTest
@testable import Tentacle

class BranchTests: XCTestCase {
    
    func testDecodingBranches() {
        let expected = [
            Branch(name: "debuggin", commit: Branch.Commit(sha: "117775803ff583c467dac3cd2c923b8d3f7d1869")),
            Branch(name: "master", commit: Branch.Commit(sha: "e1396a56055812234e97aeda78731d7228e0bbc7")),
            Branch(name: "playground", commit: Branch.Commit(sha: "131709d54e1157699e44300cb9b9f8d22f2807e7")),
            Branch(name: "release-0.17.0", commit: Branch.Commit(sha: "0f6162a44d56b3e2fc3e42d20e77b8b09bd5e00a"))
        ]

        let fixture: [Branch] = Fixture.BranchesForRepository.BranchesInReactiveTask.decodeList()!
        XCTAssertEqual(fixture, expected)
    }
}
