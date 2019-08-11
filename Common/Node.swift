//
//  Node.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

class CharacterTorch: Prop {

    override var worldTransform: float4x4 {
        guard let parent = parent else { fatalError() }

        let parentTranslation = float4x4(translation: parent.position)
        let parentRotation = float4x4(simd_quatf(float4x4(rotation: [0, -parent.rotation.z, 0])))
        let parentScale = float4x4(scaling: [1, 1, 1])

        let translationMatrix = float4x4(translation: position)
        let rotateMatrix = float4x4(quaternion)
        let scaleMatrix = float4x4(scaling: scale)

        let parentTransRot = parentTranslation * parentRotation * parentScale.inverse
        let model = translationMatrix * rotateMatrix * scaleMatrix

        return parentTransRot * model
    }
}

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

    var forwardVector: float3 {
        return normalize([sin(rotation.y), 0, cos(rotation.y)])
    }

    var rightVector: float3 {
        return [forwardVector.z, forwardVector.y, -forwardVector.x]
    }
    
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
        guard let index = (children.index { $0 === childNode }) else { return }
        children.remove(at: index)
        childNode.parent = nil
    }
}
