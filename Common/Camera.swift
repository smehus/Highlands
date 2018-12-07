//
//  Camera.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Foundation

class Camera: Node {

    var fovDegrees: Float = 70
    var fovRadians: Float {
        return radians(fromDegrees: fovDegrees)
    }

    var aspect: Float = 1
    var near: Float = 0.001
    var far: Float = 100

    var projectionMatrix: float4x4 {
        return float4x4(projectionFov: fovRadians, near: near, far: far, aspect: aspect)
    }

    var viewMatrix: float4x4 {
        let translationMatrix = float4x4(translation: position)
        let rotateMatrix = float4x4(rotation: rotation)
        let scaleMatrix = float4x4(scaling: scale)
        return (translationMatrix * rotateMatrix * scaleMatrix).inverse
    }
}
