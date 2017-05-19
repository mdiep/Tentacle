//
//  Sha.swift
//  Tentacle
//
//  Created by Romain Pouclet on 2016-12-26.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

import Foundation
import Argo
import Curry
import Runes

public struct SHA {
    public let hash: String
}

extension SHA: ResourceType {
    public static func decode(_ json: JSON) -> Decoded<SHA> {
        return curry(SHA.init)
            <^> json <| "sha"
    }

    public var hashValue: Int {
        return hash.hashValue
    }

    public static func ==(lhs: SHA, rhs: SHA) -> Bool {
        return lhs.hash == rhs.hash
    }
}

extension SHA: Encodable {
    public func encode() -> JSON {
        return .string(hash)
    }
}
