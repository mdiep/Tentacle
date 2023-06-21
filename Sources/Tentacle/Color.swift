//
//  Color.swift
//  Tentacle
//
//  Created by Romain Pouclet on 2016-07-19.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

import Foundation

#if !os(Linux)

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
    public typealias Color = UIColor
#else
    import Cocoa
    public typealias Color = NSColor
#endif

extension Color {
    internal convenience init(hex: String) {
        precondition(hex.count == 6)

        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xff0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00ff00) >>  8) / 255.0
        let b = CGFloat((rgb & 0x0000ff) >>  0) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

#endif
