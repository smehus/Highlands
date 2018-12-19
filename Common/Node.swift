//
//  Node.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

class Node {

    var name = "untitled"
    var position: float3 = [0, 0, 0]
    var rotation: float3 = [0, 0, 0] {
        didSet {
            let rotationMatrix = float4x4(rotation: rotation)
            quaternion = simd_quatf(rotationMatrix)
        }
    }
    var scale: float3 = [1, 1, 1]
    var quaternion = simd_quatf()

    var boundingBox = MDLAxisAlignedBoundingBox()
    var size: float3 {
        return boundingBox.maxBounds - boundingBox.minBounds
    }

    var modelMatrix: float4x4 {
        let translationMatrix = float4x4(translation: position)
        let rotateMatrix = float4x4(quaternion)
        // TODO: - Swith back to just 'scale' instead of scale.x etc
        let scaleMatrix = float4x4(scaling: [scale.x, scale.y, -scale.z])
        return translationMatrix * rotateMatrix * scaleMatrix
    }
}
