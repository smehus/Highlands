//
//  Patch+Extensions.swift
//  Highlands
//
//  Created by Scott Mehus on 1/28/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import Foundation

extension Patch: Equatable {

    static public func ==(lhs: Patch, rhs: Patch) -> Bool {
        assertionFailure("Need to Implement Equatable FOR PATCH"); return false
    }

    static public func != (lhs: Patch, rhs: Patch) -> Bool {
        return lhs.topLeft != rhs.topLeft ||
                lhs.topRight != rhs.topRight ||
                lhs.bottomLeft != rhs.bottomLeft ||
                lhs.bottomRight != rhs.bottomRight
    }
}
