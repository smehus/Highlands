//
//  Animation.swift
//  Highlands
//
//  Created by Scott Mehus on 12/18/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Foundation

struct Keyframe {
    var time: Float = 0
    var value: float3 = float3(0)
}

struct KeyQuaternion {
    var time: Float = 0
    var value = simd_quatf()
}

class Animation {
    var translations: [Keyframe] = []
    var rotations: [KeyQuaternion] = []
    var repeatAnimation = false

    func getTranslation(time: Float) -> float3? {
        guard let lastKeyFrame = translations.last else { return nil }

        var currentTime = time
        if let first = translations.first, first.time >= currentTime {
            return first.value
        }

        if currentTime >= lastKeyFrame.time, !repeatAnimation {
            return lastKeyFrame.value
        }

        currentTime = fmod(currentTime, lastKeyFrame.time)


        let keyFramePairs = translations.indices.dropFirst().map {
            (previous: translations[$0 - 1], next: translations[$0])
        }

        guard let (previousKey, nextKey) = ( keyFramePairs.first { currentTime < $0.next.time }) else { return nil }

        // Default interpolation formula
        let interpolant = (currentTime - previousKey.time) / (nextKey.time - previousKey.time)

        return simd_mix(previousKey.value, nextKey.value, float3(interpolant))
    }

    func getRotation(time: Float) -> simd_quatf? {
        guard let lastKeyframe = rotations.last else {
            return nil
        }

        var currentTime = time
        if let first = rotations.first, first.time >= currentTime {
            return first.value
        }

        if currentTime >= lastKeyframe.time, !repeatAnimation {
            return lastKeyframe.value
        }

        currentTime = fmod(currentTime, lastKeyframe.time)

        let keyFramePairs = rotations.indices.dropFirst().map { (previous: rotations[$0 - 1], next: rotations[$0]) }

        guard let (previousKey, nextKey) = ( keyFramePairs.first { currentTime < $0.next.time }) else {return nil }

        let interpolant = (currentTime - previousKey.time) / (nextKey.time - previousKey.time)
        return simd_slerp(previousKey.value, nextKey.value, interpolant)
    }

}

