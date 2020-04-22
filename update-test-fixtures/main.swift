//
//  main.swift
//  Tentacle
//
//  Created by Matt Diephouse on 3/3/16.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

// A "script" to automatically download the test fixtures needed for Tentacle's unit tests.
// This makes it easy to keep the fixtures up-to-date.

import Foundation
import ReactiveSwift
@testable import Tentacle

let baseURL = URL(fileURLWithPath: CommandLine.arguments[1])

let fileManager = FileManager.default
let client = Client(.dotCom)
let session = URLSession.shared
let result = SignalProducer<FixtureType, Error>(Fixture.allFixtures)
    .flatMap(.concat) { fixture -> SignalProducer<(), Error> in
        let request = client.urlRequest(for: fixture.url, contentType: fixture.contentType)
        let dataURL = baseURL.appendingPathComponent(fixture.dataFilename)
        let responseURL = baseURL.appendingPathComponent(fixture.responseFilename)
        let path = (dataURL.path as NSString).abbreviatingWithTildeInPath
        print("*** Downloading \(request.url!)\n    to \(path)")
        return session
            .reactive
            .data(with: request)
            .on(failed: { error in
                print("***** Download failed: \(error)")
            })
            .on(value: { data, response in
                
                let existing = try? Data(contentsOf: dataURL)
                let changed = existing != data
                
                if changed {
                    try! fileManager.createDirectory(at: dataURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

                    let JSONResponse = try! JSONSerialization.jsonObject(with: data, options: .allowFragments)
                    let formattedData = try! JSONSerialization.data(withJSONObject: JSONResponse, options: .prettyPrinted)
                    try? formattedData.write(to: dataURL, options: .atomic)
                }
                
                if changed || !fileManager.fileExists(atPath: responseURL.path) {
                    try? NSKeyedArchiver
                        .archivedData(withRootObject: response)
                        .write(to: responseURL, options: .atomic)
                }
            })
            .map { _, _ in () }
    }
    .wait()

switch result {
case .success:
    print("Successfully updated text fixtures")
case let .failure(error):
    print("Error updating fixtures: \(error)")
}
