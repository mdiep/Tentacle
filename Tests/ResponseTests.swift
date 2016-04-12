//
//  ResponseTests.swift
//  Tentacle
//
//  Created by Matt Diephouse on 3/17/16.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

@testable import Tentacle
import XCTest

class ResponseTests: XCTestCase {
    func testInitWithHeaderFields() {
        let headers = [
            "X-RateLimit-Remaining": "4987",
            "X-RateLimit-Reset": "1350085394",
            "Link": "<https://api.github.com/user/repos?page=3&per_page=100>; rel=\"next\", <https://api.github.com/user/repos?page=50&per_page=100>; rel=\"last\""
        ]
        
        let response = Response(headerFields: headers)
        XCTAssertEqual(response.rateLimitRemaining, 4987)
        XCTAssertEqual(response.rateLimitReset, NSDate(timeIntervalSince1970: 1350085394))
        XCTAssertEqual(
            response.links,
            [
                "next": NSURL(string: "https://api.github.com/user/repos?page=3&per_page=100")!,
                "last": NSURL(string: "https://api.github.com/user/repos?page=50&per_page=100")!,
            ]
        )
    }
    func testInitWithNoRateLimitFields() {
        let headers = [
            "Link": "<https://api.github.com/user/repos?page=3&per_page=100>; rel=\"next\", <https://api.github.com/user/repos?page=50&per_page=100>; rel=\"last\""
        ]

        let response = Response(headerFields: headers)
        XCTAssertEqual(
            response.links,
            [
                "next": NSURL(string: "https://api.github.com/user/repos?page=3&per_page=100")!,
                "last": NSURL(string: "https://api.github.com/user/repos?page=50&per_page=100")!,
            ]
        )
    }
}
