//
//  Character.swift
//  Highlands
//
//  Created by Scott Mehus on 12/19/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

class Character: Node {

    class CharacterSubmesh: Submesh {

        // Adding properties that are already in the MTKSubmesh
        var attributes: [Attributes] = []
        var indexCount: Int = 0
        var indexBuffer: MTLBuffer?
        var indexBufferOffset: Int = 0
        var indexType: MTLIndexType = .uint16
    }

    let buffers: [MTLBuffer]
    let meshNodes: [CharacterNode]
    let animations: [AnimationClip]
    let nodes: [CharacterNode]
    var currentTime: Float = 0

    init(name: String) {
        let asset = GLTFAsset(filename: name)
        buffers = asset.buffers
        animations = asset.animations
        guard !asset.scenes.isEmpty else { fatalError() }

        // The nodes that contain skinning data which bind vertices to joints.
        meshNodes = asset.scenes[0].meshNodes
        
        nodes = asset.scenes[0].nodes
        super.init()
        self.name = name
    }
}

extension Character: Renderable {

    func calculateJoints(node: CharacterNode, time: Float) {
        // 1
        if let nodeAnimation = animations[0].nodeAnimations[node.nodeIndex] {
            // 2
            if let translation = nodeAnimation.getTranslation(time: time) {
                node.translation = translation
            }
            if let rotationQuaternion = nodeAnimation.getRotation(time: time) {
                node.rotationQuaternion = rotationQuaternion
            }
        }
        // 3
        for child in node.children {
            calculateJoints(node: child, time: time)
        }
    }

    func update(deltaTime: Float) {
        guard animations.count > 0 else { return }
        currentTime += deltaTime
        let time = fmod(currentTime, animations[0].duration)
        for node in meshNodes {
            if let rootNode = node.skin?.skeletonRootNode {
                calculateJoints(node: rootNode, time: time)
            }
        }
    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, fragmentUniforms: FragmentUniforms) {
        for node in meshNodes {
            guard let mesh = node.mesh else { return }


            if let skin = node.skin {
                for (i, jointNode) in skin.jointNodes.enumerated() {
                    skin.jointMatrixPalette[i] = node.globalTransform.inverse * jointNode.globalTransform * jointNode.inverseBindTransform
                }

                let length = MemoryLayout<float4x4>.stride * skin.jointMatrixPalette.count
                let buffer = Renderer.device.makeBuffer(bytes: &skin.jointMatrixPalette, length: length, options: [])
                renderEncoder.setVertexBuffer(buffer, offset: 0, index: 21)
            }

            var uniforms = uniforms
            uniforms.modelMatrix = modelMatrix
            uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)
            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            var fragmentUniforms = fragmentUniforms
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: Int(BufferIndexFragmentUniforms.rawValue))

            for submesh in mesh.submeshes {
                renderEncoder.setRenderPipelineState(submesh.pipelineState)
                var material = submesh.material
                renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: Int(BufferIndexMaterials.rawValue))

                for attribute in submesh.attributes {
                    renderEncoder.setVertexBuffer(buffers[attribute.bufferIndex], offset: attribute.offset, index: attribute.index)
                }

                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer!,
                                                    indexBufferOffset: submesh.indexBufferOffset)
            }
        }
    }
}
