//
//  Response.swift
//  Tentacle
//
//  Created by Matt Diephouse on 3/10/16.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

import Foundation

let LinksRegex = try! NSRegularExpression(pattern: "(?<=\\A|,) *<([^>]+)>( *; *\\w+ *= *\"[^\"]+\")* *(?=\\z|,)", options: [])
let LinkParamRegex = try! NSRegularExpression(pattern: "; *(\\w+) *= *\"([^\"]+)\"", options: [])

/// Returns any links, keyed by `rel`, from the RFC 5988 link header.
private func linksInLinkHeader(header: NSString) -> [String: NSURL] {
    var links: [String: NSURL] = [:]
    for match in LinksRegex.matchesInString(header as String, options: [], range: NSMakeRange(0, header.length)) {
        let URI = header.substringWithRange(match.rangeAtIndex(1))
        let params = header.substringWithRange(match.rangeAtIndex(2)) as NSString
        guard let URL = NSURL(string: URI) else { continue }
        
        var relName: String? = nil
        for match in LinkParamRegex.matchesInString(params as String, options: [], range: NSMakeRange(0, params.length)) {
            let name = params.substringWithRange(match.rangeAtIndex(1))
            if name != "rel" { continue }
            
            relName = params.substringWithRange(match.rangeAtIndex(2))
        }
        
        if let relName = relName {
            links[relName] = URL
        }
    }
    return links
}

/// A response from the GitHub API.
public struct Response: Hashable {
    /// The number of requests remaining in the current rate limit window.
    public let rateLimitRemaining: UInt
    
    /// The time at which the current rate limit window resets
    public let rateLimitReset: NSDate
    
    /// Any links that are included in the response.
    public let links: [String: NSURL]
    
    public init(rateLimitRemaining: UInt, rateLimitReset: NSDate, links: [String: NSURL]) {
        self.rateLimitRemaining = rateLimitRemaining
        self.rateLimitReset = rateLimitReset
        self.links = links
    }
    
    /// Initialize a response with HTTP header fields.
    internal init(headerFields: [String : String]) {
        self.rateLimitRemaining = headerFields["X-RateLimit-Remaining"] != nil ? UInt(headerFields["X-RateLimit-Remaining"]!)! : UInt.max
        self.rateLimitReset = headerFields["X-RateLimit-Reset"] != nil ? NSDate(timeIntervalSince1970: NSTimeInterval(headerFields["X-RateLimit-Reset"]!)!) : NSDate.distantFuture()
        self.links = linksInLinkHeader(headerFields["Link"] ?? "")
    }
    
    public var hashValue: Int {
        return rateLimitRemaining.hashValue ^ rateLimitReset.hashValue ^ Array(links.values).reduce(0) { $0 ^ $1.hashValue }
    }
}

public func ==(lhs: Response, rhs: Response) -> Bool {
    return lhs.rateLimitRemaining == rhs.rateLimitRemaining
        && lhs.rateLimitReset == rhs.rateLimitReset
        && lhs.links == rhs.links
}
