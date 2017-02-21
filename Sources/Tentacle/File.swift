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
    /// The content path (used in update)
    public let path: String?
    /// The blob SHA of the file being replaced (used in update)
    public let sha: String?

    public init(message: String, committer: Author?, author: Author?, content: Data, branch: String?, path: String?, sha: String?) {
        self.message = message
        self.committer = committer
        self.author = author
        self.content = content
        self.branch = branch
        self.path = path
        self.sha = sha
    }

    public init(message: String, committer: Author?, author: Author?, content: Data, branch: String?) {
        self.message = message
        self.committer = committer
        self.author = author
        self.content = content
        self.branch = branch
        self.path = nil
        self.sha = nil
    }
}

extension File: RequestType {
    public typealias Response = FileResponse

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

        if let path = path {
            payload["path"] = .string(path)
        }

        if let sha = sha {
            payload["sha"] = .string(sha)
        }

        return JSON.object(payload)
    }
    
    public static func ==(lhs: File, rhs: File) -> Bool {
        return lhs.message == rhs.message
            && lhs.committer == rhs.committer
            && lhs.author == rhs.committer
            && lhs.content == rhs.content
            && lhs.branch == rhs.branch
            && lhs.path == rhs.path
            && lhs.sha == rhs.sha
    }
}
