//
//  TransformComponent.swift
//  Highlands
//
//  Created by Scott Mehus on 12/31/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

import Foundation
import ModelIO

class TransformComponent {
    let keyTransforms: [float4x4]
    let duration: Float
    var currentTransform: float4x4 = .identity()

    init(transform: MDLTransformComponent, object: MDLObject, startTime: TimeInterval, endTime: TimeInterval) {
        duration = Float(endTime - startTime)
        let frames = 1 / TimeInterval(Renderer.mtkView.preferredFramesPerSecond)
        let timeStride = stride(from: startTime, to: endTime, by: frames)
        keyTransforms = Array(timeStride).map { time in
            // Grabs the transform of usda at time - listed in the usda file?
            return MDLTransform.globalTransform(with: object, atTime: time)
        }
    }

    func setCurrentTransform(at time: Float) {
        guard duration > 0 else { currentTransform = .identity(); return }

        // Just grabs a frame as if it were looping (say if duration was 2.5 & time was 30)
        let frame = Int(fmod(time, duration) * Float(Renderer.mtkView.preferredFramesPerSecond))

        if frame < keyTransforms.count {
            currentTransform = keyTransforms[frame]
        } else {
            currentTransform = keyTransforms.last ?? .identity()

        }
    }
}
