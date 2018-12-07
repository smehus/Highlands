//
//  RendererExtensions.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

extension Renderer {
    func zoomUsing(delta: CGFloat, sensitivity: Float) {
        let cameraVector = camera.modelMatrix.upperLeft().columns.2
        camera.position += Float(delta) * sensitivity * cameraVector
    }

    func rotateUsing(translation: float2) {
        let sensitivity: Float = 0.01
        camera.position = float4x4(rotationY: -translation.x * sensitivity).upperLeft() * camera.position
        camera.rotation.y = atan2f(-camera.position.x, -camera.position.z)
    }
}
