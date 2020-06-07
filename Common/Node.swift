//
//  Node.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

class Node: Positionable {

    var name = "untitled"
    var position: SIMD3<Float> = [0, 0, 0]
    var rotation: SIMD3<Float> = [0, 0, 0] {
        didSet {
            let rotationMatrix = float4x4(rotation: rotation)
            quaternion = simd_quatf(rotationMatrix)
        }
    }
    var scale: SIMD3<Float> = [1, 1, 1]
    var quaternion = simd_quatf()

    var boundingBox = MDLAxisAlignedBoundingBox()
    var size: SIMD3<Float> {
        return boundingBox.maxBounds - boundingBox.minBounds
    }

    var parent: Node?
    var children = [Node]()

    var modelMatrix: float4x4 {
        let translationMatrix = float4x4(translation: position)
        let rotateMatrix = float4x4(quaternion)
        // TODO: - Swith back to just 'scale' instead of scale.x etc
        let scaleMatrix = float4x4(scaling: scale)
        return translationMatrix * rotateMatrix * scaleMatrix
    }

    var worldTransform: float4x4 {
        if let parent = parent {
            return parent.worldTransform * modelMatrix
        }

        return modelMatrix
    }

    var forwardVector: SIMD3<Float> {
        return normalize([sin(rotation.y), 0, cos(rotation.y)])
    }

    var rightVector: SIMD3<Float> {
        return [forwardVector.z, forwardVector.y, -forwardVector.x]
    }

    var isMovable = true
    
    func update(deltaTime: Float) {
        // override this
    }

    final func add(childNode: Node) {
        children.append(childNode)
        childNode.parent = self
    }
    final func remove(childNode: Node) {

        for child in childNode.children {
            child.parent = self
            children.append(child)
        }

        childNode.children = []
        guard let index = (children.firstIndex { $0 === childNode }) else { return }
        children.remove(at: index)
        childNode.parent = nil
    }
}
