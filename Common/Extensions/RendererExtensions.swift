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

extension Renderer {
    func lighting() -> [Light] {
        var lights: [Light] = []

        var light = buildDefaultLight()
        light.position = [-1, 0.5, -2]
        light.intensity = 2.0
        lights.append(light)

        light = buildDefaultLight()
        light.position = [0, 1, 2]
        light.intensity = 0.2
        lights.append(light)

        light = buildDefaultLight()
        light.type = Ambientlight
        light.intensity = 0.2
        lights.append(light)

        return lights
    }

    func buildDefaultLight() -> Light {
        var light = Light()
        light.position = [0, 0, 0]
        light.color = [1, 1, 1]
        light.specularColor = [0.6, 0.6, 0.6]
        light.intensity = 1
        light.attenuation = float3(1, 0, 0)
        light.type = Sunlight
        return light
    }
}
