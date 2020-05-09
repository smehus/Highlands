//
//  Transform.swift
//  Highlands
//
//  Created by Scott Mehus on 1/10/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

import Foundation

protocol Positionable {
    var position: SIMD3<Float> { get set }
    var isMovable: Bool { get }
}

extension Positionable {
    var isMovable: Bool {
        return true
    }
}

/// Used for instances
class Transform: Positionable {
    var position = SIMD3<Float>(repeating: 0)
    var rotation = SIMD3<Float>(repeating: 0)
    var scale = SIMD3<Float>(repeating: 1)

    var modelMatrix: float4x4 {
        let translationMatrix = float4x4(translation: position)
        let rotationMatrix = float4x4(rotation: rotation)
        let scaleMatrix = float4x4(scaling: scale)
        return translationMatrix * rotationMatrix * scaleMatrix
    }

    var normalMatrix: float3x3 {
        return float3x3(normalFrom4x4: modelMatrix)
    }
}

extension Transform: Equatable {
    static func ==(lhs: Transform, rhs: Transform) -> Bool {
        let equalPosition = lhs.position == rhs.position
        let equalRotation = lhs.rotation == rhs.rotation
        let equalScale = lhs.scale == rhs.scale
        let reduced = [equalPosition, equalRotation, equalScale].reduce(true) { $0 && $1 }
        let equated = equalPosition && equalRotation && equalScale
        assert(reduced == equated)
        return reduced
    }
}
