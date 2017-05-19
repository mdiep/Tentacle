//
//  File.swift
//  Tentacle
//
//  Created by Romain Pouclet on 2016-12-21.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

import Foundation
import Argo
import Runes
import Curry

extension Repository {
    // https://developer.github.com/v3/repos/contents/#create-a-file
    internal func create(file: File, atPath path: String, inBranch branch: String? = nil) -> Request {
        let queryItems: [URLQueryItem]
        if let branch = branch {
            queryItems = [ URLQueryItem(name: "branch", value: branch) ]
        } else {
            queryItems = []
        }
        return Request(
            method: .put,
            path: "/repos/\(owner)/\(name)/contents/\(path)",
            queryItems: queryItems
        )
    }
}

public struct File {
    /// Commit message
    public let message: String
    /// The committer of the commit
    public let committer: Author?
    /// The author of the commit
    public let author: Author?
    /// Content of the file to create
    public let content: Data
    /// Branch in which the file will be created
    public let branch: String?

    public init(message: String, committer: Author?, author: Author?, content: Data, branch: String?) {
        self.message = message
        self.committer = committer
        self.author = author
        self.content = content
        self.branch = branch
    }
}

extension File: Encodable, Hashable {
    public var hashValue: Int {
        return message.hashValue
    }

    public func encode() -> JSON {
        var payload: [String: JSON] = [
            "message": .string(message),
            "content": .string(content.base64EncodedString())
        ]

        if let author = author {
            payload["author"] = author.encode()
        }

        if let committer = committer {
            payload["committer"] = committer.encode()
        }

        if let branch = branch {
            payload["branch"] = .string(branch)
        }

        return JSON.object(payload)
    }
    
    public static func ==(lhs: File, rhs: File) -> Bool {
        return lhs.message == rhs.message
            && lhs.committer == rhs.committer
            && lhs.author == rhs.committer
            && lhs.content == rhs.content
            && lhs.branch == rhs.branch
    }
}

struct Update {
    /// The file to update
    let file: File

    /// The content path
    let path: String

    /// The blob SHA of the file being replaced
    let sha: SHA
}

extension Update: RequestType {
    public typealias Response = FileResponse

    public var hashValue: Int {
        return path.hashValue ^ sha.hashValue
    }

    func encode() -> JSON {
        guard case var .object(payload) = file.encode() else {
            fatalError("Invalid `File` object")
        }

        payload["path"] = .string(path)
        payload["sha"] = sha.encode()

        return .object(payload)
    }

    public static func ==(lhs: Update, rhs: Update) -> Bool {
        return lhs.file == rhs.file
            && lhs.path == rhs.path
            && lhs.sha == rhs.sha
    }

}
