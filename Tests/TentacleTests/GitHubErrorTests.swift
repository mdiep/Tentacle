//
//  GitHubErrorTests.swift
//  Tentacle
//
//  Created by Matt Diephouse on 3/4/16.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

@testable import Tentacle
import XCTest

class GitHubErrorTests: XCTestCase {
    func testDecode() {
        let expected = GitHubError(message: "Not Found")
        XCTAssertEqual(Fixture.Release.Nonexistent.decode(), expected)
    }
}
