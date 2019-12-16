//
//  Transform.swift
//  Highlands
//
//  Created by Scott Mehus on 1/10/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

import Foundation

struct Transform {
    var position = SIMD3<Float>(0)
    var rotation = SIMD3<Float>(0)
    var scale = SIMD3<Float>(1)

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
