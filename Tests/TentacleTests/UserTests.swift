//
//  UserTests.swift
//  Tentacle
//
//  Created by Matt Diephouse on 4/12/16.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

@testable import Tentacle
import XCTest

class UserTests: XCTestCase {
    func testDecodeMdiep() {
        let expected = UserProfile(
            user: UserInfo(
                id: 1302,
                user: User("mdiep"),
                url: URL(string: "https://github.com/mdiep")!,
                avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1302?v=4")!,
                type: .user
            ),
            joinedDate: Date(timeIntervalSince1970: 1204155107),
            name: "Matt Diephouse",
            email: nil,
            websiteURL: "http://matt.diephouse.com",
            company: nil
        )
        XCTAssertEqual(Fixture.UserProfile.mdiep.decode(), expected)
    }

    func testDecodeTest() {
        let expected = UserProfile(
            user: UserInfo(
                id: 383316,
                user: User("test"),
                url: URL(string: "https://github.com/test")!,
                avatarURL: URL(string: "https://avatars.githubusercontent.com/u/383316?v=4")!,
                type: .user
            ),
            joinedDate: Date(timeIntervalSince1970: 1283337552),
            name: nil,
            email: nil,
            websiteURL: "",
            company: nil
        )
        XCTAssertEqual(Fixture.UserProfile.test.decode(), expected)
    }
}
