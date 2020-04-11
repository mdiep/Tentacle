//
//  ClientTests.swift
//  Tentacle
//
//  Created by Matt Diephouse on 3/5/16.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

import ReactiveSwift
import Tentacle
import XCTest

public func == <T: Equatable, Error: Equatable> (left: Result<[T], Error>, right: Result<[T], Error>) -> Bool {
    if let left = left.value, let right = right.value {
        return left == right
    } else if let left = left.error, let right = right.error {
        return left == right
    }
    return false
}

public func == <T: Equatable, Error: Equatable> (left: Result<[[T]], Error>, right: Result<[[T]], Error>) -> Bool {
    if let left = left.value, let right = right.value {
        guard left.count == right.count else { return false }
        for idx in left.indices {
            if left[idx] != right[idx] {
                return false
            }
        }
        return true
    } else if let left = left.error, let right = right.error {
        return left == right
    }
    return false
}

func ExpectResult
    <O: ResourceType>
    (_ producer: SignalProducer<(Response, O), Client.Error>, _ result: Result<[O], Client.Error>, file: StaticString = #file, line: UInt = #line)
{
    let actual = producer.map { $0.1 }.collect().single()!
    let message: String
    switch result {
    case let .success(value):
        message = "\(actual) is not equal to \(value)"
    case let .failure(error):
        message = "\(actual) is not equal to \(error)"
    }
    XCTAssertTrue(actual == result, message, file: file, line: line)
}

func ExpectResult
    <F: EndpointFixtureType, O: ResourceType>
    (_ producer: SignalProducer<(Response, O), Client.Error>, _ result: Result<[F], Client.Error>, file: StaticString = #file, line: UInt = #line)
{
    let expected = result.map { fixtures -> [O] in fixtures.map { $0.decode()! } }
    ExpectResult(producer, expected, file: file, line: line)
}

func ExpectResult
    <O: ResourceType>
    (_ producer: SignalProducer<(Response, [O]), Client.Error>, _ result: Result<[[O]], Client.Error>, file: StaticString = #file, line: UInt = #line)
{
    let actual = producer.map { $0.1 }.collect().single()!
    let message: String
    switch result {
    case let .success(value):
        message = "\(actual) is not equal to \(value)"
    case let .failure(error):
        message = "\(actual) is not equal to \(error)"
    }
    XCTAssertTrue(actual == result, message, file: file, line: line)
}

func ExpectResult
    <F: EndpointFixtureType, O: ResourceType, C: Collection>
    (_ producer: SignalProducer<(Response, [O]), Client.Error>, _ result: Result<C, Client.Error>, file: StaticString = #file, line: UInt = #line) where C.Iterator.Element == F
{
    let expected = result.map { fixtures -> [[O]] in fixtures.map { $0.decode()! } }
    ExpectResult(producer, expected, file: file, line: line)
}

func ExpectError
    <O: ResourceType>
    (_ producer: SignalProducer<(Response, O), Client.Error>, _ error: Client.Error, file: StaticString = #file, line: UInt = #line)
{
    ExpectResult(producer, Result<[O], Client.Error>.failure(error), file: file, line: line)
}

func ExpectFixtures
    <F: EndpointFixtureType, O: ResourceType>
    (_ producer: SignalProducer<(Response, O), Client.Error>, _ fixtures: F..., file: StaticString = #file, line: UInt = #line)
{
    ExpectResult(producer, Result<[F], Client.Error>.success(fixtures), file: file, line: line)
}

func ExpectFixtures
    <F: EndpointFixtureType, O: ResourceType, C: Collection>
    (_ producer: SignalProducer<(Response, [O]), Client.Error>, _ fixtures: C, file: StaticString = #file, line: UInt = #line) where C.Iterator.Element == F
{
    ExpectResult(producer, .success(fixtures), file: file, line: line)
}

class ClientTests: XCTestCase {
    private let client = Client(.dotCom)

    override func setUp() {
        HTTPStub.shared.stubRequests = { request in
            guard let fixture = Fixture.fixtureForURL(request.url!) else {
                fatalError("No Fixture found for url \(request.url!)")
            }

            return fixture
        }
    }
    
    func testReleasesInRepository() {
        let fixtures = Fixture.Releases.Carthage

        ExpectFixtures(
            client.execute(fixtures[0].request),
            fixtures
        )
    }
    
    func testReleasesInRepositoryPage2() {
        let fixtures = Fixture.Releases.Carthage
        ExpectFixtures(
            client.execute(fixtures[0].request, page: 2),
            fixtures.dropFirst()
        )
    }
    
    func testReleaseForTagInRepository() {
        let fixture = Fixture.Release.Carthage0_15
        ExpectFixtures(
            client.execute(fixture.request),
            fixture
        )
    }
    
    func testReleaseForTagInRepositoryNonExistent() {
        let fixture = Fixture.Release.Nonexistent
        ExpectError(
            client.execute(fixture.request),
            .doesNotExist
        )
    }
    
    func testReleaseForTagInRepositoryTagOnly() {
        let fixture = Fixture.Release.TagOnly
        ExpectError(
            client.execute(fixture.request),
            .doesNotExist
        )
    }
    
    func testDownloadAsset() {
        let release: Release = Fixture.Release.MDPSplitView1_0_2.decode()!
        let asset = release.assets
            .first { $0.name == "MDPSplitView.framework.zip" }!

        let result = client
            .download(asset: asset)
            .map { url in
                return try! Data(contentsOf: url)
            }
            .single()!
        XCTAssertEqual(result.value, Fixture.Release.Asset.MDPSplitView_framework_zip.data)
    }
    
    func testUserWithLogin() {
        let fixture = Fixture.UserProfile.mdiep
        ExpectFixtures(client.execute(fixture.request), fixture)
    }
}
