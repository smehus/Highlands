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

func generateBallTranslations() -> [Keyframe] {
    return [
        Keyframe(time: 0,    value: [-1, 0, 0]),
        Keyframe(time: 0.17, value: [0, 0.5, 0]),
        Keyframe(time: 0.35, value: [1, 0, 0]),
        Keyframe(time: 1.0,  value: [1, 0, 0]),
        Keyframe(time: 1.17, value: [0, 0.5, 0]),
        Keyframe(time: 1.35, value: [-1, 0, 0]),
        Keyframe(time: 2,    value: [-1, 0, 0])
    ]
}

func generateBallRotations() -> [KeyQuaternion] {
    return [
        KeyQuaternion(time: 0,    value: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)),
        KeyQuaternion(time: 0.08, value: simd_quatf(angle: .pi/2, axis: [0, 0, -1])),
        KeyQuaternion(time: 0.17, value: simd_quatf(angle: .pi, axis: [0, 0, -1])),
        KeyQuaternion(time: 0.26, value: simd_quatf(angle: .pi + .pi/2, axis: [0, 0, -1])),
        KeyQuaternion(time: 0.35, value: simd_quatf(angle: 0, axis: [0, 0, -1])),
        KeyQuaternion(time: 1.0,  value: simd_quatf(angle: 0, axis: [0, 0, -1])),
        KeyQuaternion(time: 1.08, value: simd_quatf(angle: .pi + .pi/2, axis: [0, 0, -1])),
        KeyQuaternion(time: 1.17, value: simd_quatf(angle: .pi, axis: [0, 0, -1])),
        KeyQuaternion(time: 1.26, value: simd_quatf(angle: .pi/2, axis: [0, 0, -1])),
        KeyQuaternion(time: 1.35, value: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)),
        KeyQuaternion(time: 2,    value: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
    ]
}

