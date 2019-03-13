//
//  Camera.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Foundation

class Camera: Node {

    var fovDegrees: Float = 90
    var fovRadians: Float {
        return radians(fromDegrees: fovDegrees)
    }

    var aspect: Float = 1
    var near: Float = 0.1
    var far: Float = 25

    var projectionMatrix: float4x4 {
//        return float4x4(projectionFov: fovRadians, near: near, far: far, aspect: aspect)
//        return float4x4(projectionFov: fovRadians, aspectRaptio: aspect, nearZ: near, farZ: far)
        return float4x4(projectionFov: fovRadians, aspectRatio: aspect, nearZ: near, farZ: far)
    }

    var viewMatrix: float4x4 {
        let translationMatrix = float4x4(translation: position)
        let rotateMatrix = float4x4(rotation: rotation)
        let scaleMatrix = float4x4(scaling: scale)
        return (translationMatrix * rotateMatrix * scaleMatrix).inverse
    }
}

class OrthographicCamera: Camera {
    var rect = Rectangle(left: 10, right: 10,
                         top: 10, bottom: 10)
    override init() {
        super.init()
    }

    init(rect: Rectangle, near: Float, far: Float) {
        super.init()
        self.rect = rect
        self.near = near
        self.far = far
    }

    // Uses super class viewMatrix:

    override var projectionMatrix: float4x4 {
        return float4x4(orthographic: rect, near: near, far: far)
    }
}

class ThirdPersonCamera: Camera {

    var focus: Node
    var focusDistance: Float = 3
    var focusHeight: Float = 1.5

    init(focus: Node) {
        self.focus = focus
        super.init()
    }

    override var viewMatrix: float4x4 {
        setRotatingCamera()
//        setNonRotatingCamera()
        return super.viewMatrix
    }

    private func setNonRotatingCamera() {
        position = float3(focus.position.x, focus.position.y - focusDistance, focus.position.z - focusDistance)
        position.y = 10
        rotation.x = radians(fromDegrees: 90)
    }

    private func setRotatingCamera() {
        position = focus.position - focusDistance * focus.forwardVector
        position.y = focus.position.y + focusHeight
        rotation.y = focus.rotation.y
    }
}
