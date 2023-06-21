//
//  Fixtures.swift
//  Tentacle
//
//  Created by Matt Diephouse on 3/3/16.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

import Foundation
@testable import Tentacle

/// A dummy class, so we can ask for the current bundle in Fixture.URL
private class ImportedWithFixture { }

protocol FixtureType {
    var url: URL { get }
    var contentType: String { get }
}

protocol EndpointFixtureType: FixtureType {
    associatedtype Value
    var request: Request<Value> { get }
    var page: UInt? { get }
    var perPage: UInt? { get }
}

extension FixtureType {
    /// The filename used for the local fixture, without an extension
    private func filename(withExtension ext: String) -> String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        let path = (components.path as NSString)
            .pathComponents
            .dropFirst()
            .joined(separator: "-")
        
        let query = components.queryItems?
            .map { item in
                if let value = item.value {
                    return "\(item.name)-\(value)"
                } else {
                    return item.name
                }
            }
            .joined(separator: "-")
        
        if let query = query, query != "" {
            return "\(path).\(query).\(ext)"
        }
        return "\(path).\(ext)"
    }
    
    /// The filename used for the local fixture's data.
    var dataFilename: String {
        return filename(withExtension: Fixture.DataExtension)
    }
    
    /// The filename used for the local fixture's HTTP response.
    var responseFilename: String {
        return filename(withExtension: Fixture.ResponseExtension)
    }
    
    private func fileURL(withExtension ext: String) -> URL {
        let filename = self.filename(withExtension: ext) as NSString
        #if SWIFT_PACKAGE
            return URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures")
                .appendingPathComponent(filename as String)
        #else
            let bundle = Bundle(for: ImportedWithFixture.self)
            return bundle.url(forResource: filename.deletingPathExtension, withExtension: filename.pathExtension)!
        #endif
    }
    
    /// The URL of the fixture's data within the test bundle.
    var dataFileURL: URL {
        return fileURL(withExtension: Fixture.DataExtension)
    }
    
    /// The URL of the fixture's HTTP response within the test bundle.
    var responseFileURL: URL {
        return fileURL(withExtension: Fixture.ResponseExtension)
    }
    
    /// The data from the endpoint.
    var data: Data {
       return (try! Data(contentsOf: dataFileURL))
    }
    
    /// The HTTP response from the endpoint.
    var response: HTTPURLResponse {
        let data = try! Data(contentsOf: responseFileURL)
        let unarchiver = try! NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        return try! unarchiver.decodeTopLevelObject(of: HTTPURLResponse.self, forKey: "root")!
    }
}

extension EndpointFixtureType {
    /// The URL of the fixture on the API.
    var url: URL {
        return URL(.dotCom, request, page: page, perPage: perPage)
    }
    
    /// Decode the fixture's JSON as an object of the returned type.
    func decode<Object: Decodable>() -> Object? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601)

        return try? decoder.decode(Object.self, from: data)
    }
    
    /// Decode the fixture's JSON as an array of objects of the returned type.
    func decodeList<Object: Decodable>() -> [Object]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601)

        return try? decoder.decode([Object].self, from: data)
    }
}

extension Request: EndpointFixtureType {
    internal var contentType: String {
        return Client.APIContentType
    }
    
    internal var request: Request<Value> {
        return self
    }
    
    internal var page: UInt? {
        return nil
    }
    
    internal var perPage: UInt? {
        return nil
    }
}

struct Fixture {
    fileprivate static let DataExtension = "data"
    fileprivate static let ResponseExtension = "response"
    
    static var allFixtures: [FixtureType] = [
        Repositories.Tentacle,
        LatestRelease.release,
        Release.Carthage0_15,
        Release.MDPSplitView1_0_2,
        Release.Nonexistent,
        Release.TagOnly,
        Release.Asset.MDPSplitView_framework_zip,
        Releases.Carthage[0],
        Releases.Carthage[1],
        UserProfile.mdiep,
        UserProfile.test,
        IssuesInRepository.PalleasOpensource,
        IssueInRepository.Issue1InSampleRepository,
        CommentsOnIssue.CommentsOnIssueInSampleRepository,
        RepositoriesForUser.RepositoriesForPalleasOpensource,
        RepositoriesForOrganization.RepositoriesForRACCommunity,
        FileForRepository.ReadMeForSampleRepository,
        FileForRepository.SubmoduleInTentacle,
        FileForRepository.DirectoryInSampleRepository,
        FileForRepository.SymlinkInSampleRepository,
        BranchesForRepository.BranchesInReactiveTask,
        TreeForRepository.TreeInSampleRepository
    ]
    
    /// Returns the fixture for the given URL, or nil if no such fixture exists.
    static func fixtureForURL(_ url: URL) -> FixtureType? {
        return allFixtures.first { $0.url == url }
    }

    struct LatestRelease {
        static let release = Repository(owner: "mdiep", name: "MDPSplitView").latestRelease
    }
    
    struct Release {
        static let Carthage0_15 = Repository(owner: "Carthage", name: "Carthage").release(forTag: "0.15")
        static let MDPSplitView1_0_2 = Repository(owner: "mdiep", name: "MDPSplitView").release(forTag: "1.0.2")
        static let Nonexistent = Repository(owner: "mdiep", name: "NonExistent").release(forTag: "tag")
        static let TagOnly = Repository(owner: "torvalds", name: "linux").release(forTag: "v4.4")

        struct Asset: FixtureType {
            static let MDPSplitView_framework_zip = Asset("https://api.github.com/repos/mdiep/MDPSplitView/releases/assets/433845")
            
            let url: URL
            let contentType = Client.DownloadContentType
            
            init(_ URLString: String) {
                url = URL(string: URLString)!
            }
        }
    }

    struct Repositories {
        static let Tentacle = Repository(owner: "mdiep", name: "Tentacle").info
    }

    struct Releases: EndpointFixtureType {
        static let Carthage = [
            Releases(Repository(owner: "Carthage", name: "Carthage").releases, 1, 30),
            Releases(Repository(owner: "Carthage", name: "Carthage").releases, 2, 30)
        ]
        
        let request: Request<[Tentacle.Release]>
        let page: UInt?
        let perPage: UInt?
        let contentType = Client.APIContentType
        
        init(_ request: Request<[Tentacle.Release]>, _ page: UInt?, _ perPage: UInt?) {
            self.request = request
            self.page = page
            self.perPage = perPage
        }
    }
    
    struct UserProfile {
        static let mdiep = User("mdiep").profile
        static let test = User("test").profile
    }

    struct IssuesInRepository {
        static let PalleasOpensource = Repository(owner: "Palleas-opensource", name: "Sample-repository").issues
    }

    struct IssueInRepository {
        static let Issue1InSampleRepository = Repository(owner: "Palleas-opensource", name: "Sample-repository").issue(id: 1)
    }

    struct CommentsOnIssue {
        static let CommentsOnIssueInSampleRepository = Repository(owner: "Palleas-Opensource", name: "Sample-repository").comments(onIssue: 1)
    }

    struct RepositoriesForUser {
        static let RepositoriesForPalleasOpensource = User("Palleas-Opensource").repositories
    }

    struct RepositoriesForOrganization {
        static let RepositoriesForRACCommunity = Organization("raccommunity").repositories
    }

    struct FileForRepository {
        static let ReadMeForSampleRepository = Repository(owner: "Palleas-opensource", name: "Sample-repository").content(atPath: "README.md")
        static let SubmoduleInTentacle = Repository(owner: "mdiep", name: "Tentacle").content(atPath: "Carthage/Checkouts/ReactiveSwift")
        static let DirectoryInSampleRepository = Repository(owner: "Palleas-opensource", name: "Sample-repository").content(atPath: "Tools")
        static let SymlinkInSampleRepository = Repository(owner: "Palleas-opensource", name: "Sample-repository").content(atPath: "Tools/say")
    }

    struct BranchesForRepository {
        static let BranchesInReactiveTask = Repository(owner: "Carthage", name: "ReactiveTask").branches
    }

    struct TreeForRepository {
        static let TreeInSampleRepository = Repository(owner: "Palleas-opensource", name: "Sample-repository")
            .tree(atRef: "0c0dfafa361836e11aedcbb95c1f05d3f654aef0", recursive: false)
    }
}
