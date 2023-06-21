//
//  Label.swift
//  Tentacle
//
//  Created by Romain Pouclet on 2016-05-23.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

import Foundation

public struct Label: CustomStringConvertible, ResourceType {
    public let name: String

    #if os(Linux)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
    }

    public init(name: String) {
        self.name = name
    }
    #else
    public let color: Color

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.color = Color(hex: try container.decode(String.self, forKey: .color))
    }

    public init(name: String, color: Color) {
        self.name = name
        self.color = color
    }
    #endif

    public var description: String {
        return name
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case color
    }
}

extension Label: Hashable {
    public static func ==(lhs: Label, rhs: Label) -> Bool {
        return lhs.name == rhs.name
    }
}

