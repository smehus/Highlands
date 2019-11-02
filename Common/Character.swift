//
//  Character.swift
//  Highlands
//
//  Created by Scott Mehus on 12/19/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

class CharacterTorch: Prop {

    static let localPosition: float3 = [0.14, 0.85, -1.8]

    override var worldTransform: float4x4 {
        guard let parent = parent else { fatalError() }

        let parentTranslation = float4x4(translation: parent.position)
        // This is for if we want the model to be upright (normal in blender)
        // rather than compensating for the shitty mixamo models
//        let parentRotation = float4x4(simd_quatf(float4x4(rotation: [0, -parent.rotation.z, 0])))
        let parentRotation = float4x4(parent.quaternion)
        let parentScale = float4x4(scaling: [1, 1, 1])

        let translationMatrix = float4x4(translation: position)
        let rotateMatrix = float4x4(quaternion)
        let scaleMatrix = float4x4(scaling: scale)

        let parentTransRot = parentTranslation * parentRotation * parentScale.inverse
        let model = translationMatrix * rotateMatrix * scaleMatrix

        return parentTransRot * model
    }
}

class Character: Node {

    class CharacterSubmesh: Submesh {

        // Adding properties that are already in the MTKSubmesh
        var attributes: [Attributes] = []
        var indexCount: Int = 0
        var indexBuffer: MTLBuffer?
        var indexBufferOffset: Int = 0
        var indexType: MTLIndexType = .uint16
    }

    var debugBoundingBox: DebugBoundingBox?
    override var boundingBox: MDLAxisAlignedBoundingBox {
        didSet {
            debugBoundingBox = DebugBoundingBox(boundingBox: boundingBox)
        }
    }

    let buffers: [MTLBuffer]
    let meshNodes: [CharacterNode]
    let animations: [AnimationClip]
    let nodes: [CharacterNode]
    var currentTime: Float = 0
    var currentAnimation: AnimationClip?
    var currentAnimationPlaying = false
    var samplerState: MTLSamplerState
    var shadowInstanceCount: Int = 0

    let heightCalculatePipelineState: MTLComputePipelineState
    let needsXRotationFix = true
    let heightBuffer: MTLBuffer

    let patches: [Patch]
    var currentPatch: Patch?
    var positionInPatch: PatchPositions?

    init(name: String) {
        let asset = GLTFAsset(filename: name)
        buffers = asset.buffers
        animations = asset.animations
        guard !asset.scenes.isEmpty else { fatalError() }

        // The nodes that contain skinning data which bind vertices to joints.
        meshNodes = asset.scenes[0].meshNodes
        
        nodes = asset.scenes[0].nodes

        samplerState = Character.buildSamplerState()
        heightCalculatePipelineState = Character.buildComputePipelineState()

        heightBuffer = Renderer.device.makeBuffer(length: MemoryLayout<float3>.size, options: .storageModeShared)!

        let terrainPatches = Terrain.createControlPoints(patches: Terrain.patches,
                                              size: (width: Terrain.terrainParams.size.x,
                                                     height: Terrain.terrainParams.size.y))


        patches = terrainPatches.patches

        super.init()
        self.name = name
    }

    private static func buildSamplerState() -> MTLSamplerState {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.mipFilter = .linear
        // TODO: I don't know why this is crashing me....
//        descriptor.maxAnisotropy = 0
        guard let state = Renderer.device.makeSamplerState(descriptor: descriptor) else {
            fatalError()
        }

        return state
    }


    override var forwardVector: float3 {
        return normalize([sin(-rotation.z), 0, cos(-rotation.z)])
    }

    override func update(deltaTime: Float) {

        currentPatch = patch(for: position)
        if let pos = positionInPatch(patch: currentPatch) {
            positionInPatch = PatchPositions(lowerPosition: pos.lower, upperPosition: pos.upper, realPosition: worldTransform.columns.3.xyz)
        }

        if position.y == 0 {
            let pointer = heightBuffer.contents().bindMemory(to: Float.self, capacity: 1)
            position.y = pointer.pointee
        }

        guard let animation = currentAnimation, currentAnimationPlaying == true else {
            return
        }

        currentTime += deltaTime
        let time = fmod(currentTime, animation.duration)
        for nodeAnimation in animation.nodeAnimations {

            let speed = animation.speed
            let animation = nodeAnimation.value
            animation.speed = speed

            guard let node = animation.node else { continue }

            if let translation = animation.getTranslation(time: time) {
                node.translation = translation
            }

            if let rotationQuaternion = animation.getRotation(time: time) {
                node.rotationQuaternion = rotationQuaternion
            }
        }

        let pointer = heightBuffer.contents().bindMemory(to: Float.self, capacity: 1)
        position.y = pointer.pointee
    }

    func setLeftRotation(rotationSpeed: Float) {
        if needsXRotationFix {
            rotation.z += rotationSpeed
        } else {
            rotation.y -= rotationSpeed
        }
    }

    func setRightRotation(rotationSpeed: Float) {
        if needsXRotationFix {
            rotation.z -= rotationSpeed
        } else {
            rotation.y += rotationSpeed
        }
    }

    func patch(for location: float3) -> Patch? {
        let foundPatches = patches.filter { (patch) -> Bool in
            let horizontal = patch.topLeft.x < location.x && patch.topRight.x > location.x
            let vertical = patch.topLeft.z > location.z && patch.bottomLeft.z < location.z

            return horizontal && vertical
        }

//        print("**** patches found for position \(foundPatches.count)")
        guard let patch = foundPatches.first else { return nil }

        if let current = currentPatch, current != patch {
            print("*** UPDATE CURRENT PATCH \(patch)")
        }

        return patch
    }
}

extension Patch: Equatable {

    static public func ==(lhs: Patch, rhs: Patch) -> Bool {
        assertionFailure("Need to Implement Equatable FOR PATCH"); return false
    }

    static public func != (lhs: Patch, rhs: Patch) -> Bool {
        return lhs.topLeft != rhs.topLeft ||
                lhs.topRight != rhs.topRight ||
                lhs.bottomLeft != rhs.bottomLeft ||
                lhs.bottomRight != rhs.bottomRight
    }
}

extension Character: Renderable {

    func runAnimation(clip animationClip: AnimationClip? = nil) {
        var clip = animationClip
        if clip == nil {
            guard animations.count > 0 else { return }
            clip = animations[0]
        } else {
            clip = animationClip
        }
        currentAnimation = clip
        currentTime = 0
        currentAnimationPlaying = true
        // immediately update the initial pose
        update(deltaTime: 0)
    }

    func runAnimation(name: String) {
        guard let clip = (animations.filter { $0.name == name }).first else {
            return
        }

        runAnimation(clip: clip)
    }

    func pauseAnimation() {
        currentAnimationPlaying = false
    }

    func resumeAnimation() {
        currentAnimationPlaying = true
    }

    func stopAnimation() {
        currentAnimation = nil
        currentAnimationPlaying = false
    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
//        renderEncoder.setFrontFacing(.clockwise)

        for node in meshNodes {
            guard let mesh = node.mesh else { continue }

            if let skin = node.skin {
                for (i, jointNode) in skin.jointNodes.enumerated() {
                    skin.jointMatrixPalette[i] = node.globalTransform.inverse * jointNode.globalTransform * jointNode.inverseBindTransform
                }

                let length = MemoryLayout<float4x4>.stride * skin.jointMatrixPalette.count
                let buffer = Renderer.device.makeBuffer(bytes: &skin.jointMatrixPalette, length: length, options: [])
                renderEncoder.setVertexBuffer(buffer, offset: 0, index: 21)
            }

            var uniforms = vertex
            uniforms.modelMatrix = worldTransform
            uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

            renderEncoder.setFragmentSamplerState(samplerState, index: 0)

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            for submesh in mesh.submeshes {
                renderEncoder.setRenderPipelineState(submesh.pipelineState)

                // Set the texture
                renderEncoder.setFragmentTexture(submesh.textures.baseColor, index: Int(BaseColorTexture.rawValue))

                // Set Material
                var material = submesh.material
                renderEncoder.setFragmentBytes(&material,
                                               length: MemoryLayout<Material>.stride,
                                               index: Int(BufferIndexMaterials.rawValue))

                for attribute in submesh.attributes {
                    renderEncoder.setVertexBuffer(buffers[attribute.bufferIndex],
                                                  offset: attribute.offset,
                                                  index: attribute.index)
                }

                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer!,
                                                    indexBufferOffset: submesh.indexBufferOffset)
            }

            if debugRenderBoundingBox {
                debugBoundingBox?.render(renderEncoder: renderEncoder, uniforms: uniforms)
            }
        }
    }

    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms, startingIndex: Int) {
/*
        for node in meshNodes {
            guard let mesh = node.mesh else { continue }

            if let skin = node.skin {
                for (i, jointNode) in skin.jointNodes.enumerated() {
                    skin.jointMatrixPalette[i] = node.globalTransform.inverse * jointNode.globalTransform * jointNode.inverseBindTransform
                }

                let length = MemoryLayout<float4x4>.stride * skin.jointMatrixPalette.count
                let buffer = Renderer.device.makeBuffer(bytes: &skin.jointMatrixPalette, length: length, options: [])
                renderEncoder.setVertexBuffer(buffer, offset: 0, index: 21)
            }

            var uniforms = vertex
            uniforms.modelMatrix = worldTransform
            uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

            renderEncoder.setFragmentSamplerState(samplerState, index: 0)

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            for submesh in mesh.submeshes {
                renderEncoder.setRenderPipelineState(submesh.shadowPipelineSTate)

                if submesh.textures.baseColor == nil {
                    print("🧲 TEXTURE BASE COLOR NIL")
                }

                // Set the texture
                renderEncoder.setFragmentTexture(submesh.textures.baseColor, index: Int(BaseColorTexture.rawValue))

                // Set Material
                var material = submesh.material
                renderEncoder.setFragmentBytes(&material,
                                               length: MemoryLayout<Material>.stride,
                                               index: Int(BufferIndexMaterials.rawValue))

                for attribute in submesh.attributes {
                    renderEncoder.setVertexBuffer(buffers[attribute.bufferIndex],
                                                  offset: attribute.offset,
                                                  index: attribute.index)
                }

                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer!,
                                                    indexBufferOffset: submesh.indexBufferOffset)
            }

        }
 */
    }

    static func buildComputePipelineState() -> MTLComputePipelineState {
        guard let kernelFunction = Renderer.library?.makeFunction(name: "calculate_height") else {
            fatalError("Tessellation shader function not found")
        }

        return try! Renderer.device.makeComputePipelineState(function: kernelFunction)
    }

    func calculateHeight(computeEncoder: MTLComputeCommandEncoder,
                         heightMapTexture: MTLTexture,
                         terrain: TerrainParams,
                         uniforms: Uniforms,
                         controlPointsBuffer: MTLBuffer?) {

        guard var patch = currentPatch else { return }
        guard var patchPositions = positionInPatch else { return }

//        var position = self.worldTransform.columns.3.xyz
        var terrainParams = terrain
        var uniforms = uniforms

        computeEncoder.setComputePipelineState(heightCalculatePipelineState)
        computeEncoder.setBytes(&patchPositions, length: MemoryLayout<PatchPositions>.stride, index: 0)
        computeEncoder.setBuffer(heightBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&terrainParams, length: MemoryLayout<TerrainParams>.stride, index: 2)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 3)
        computeEncoder.setTexture(heightMapTexture, index: 0)
        computeEncoder.setBuffer(controlPointsBuffer, offset: 0, index: 4)
        computeEncoder.setBytes(&patch, length: MemoryLayout<Patch>.stride, index: 5)

        computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                            threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
    }

    func positionInPatch(patch: Patch?) -> (lower: float3, upper: float3)? {
        guard let patch = patch else { return nil }
        let worldPos = self.worldTransform.columns.3.xyz

        let width = (patch.topRight.x - patch.topLeft.x) / 16
        let height = (patch.topLeft.z - patch.bottomLeft.z) / 16

        let widthSegments: [Float] = Array(stride(from: patch.topLeft.x, through: patch.topRight.x, by: width))
        let heightSegments = Array(stride(from: patch.bottomLeft.z, through: patch.topLeft.z, by: height))

        let calculate: (Float, [Float]) -> (lower: Float, upper: Float) = { input, collection in
//            let value = collection.sorted { (first, second) -> Bool in
//                return abs(input - first) < abs(input - second)
//            }.first
//
//            return value!

            let lowerValue = collection.reversed().filter { $0 < input }.first!
            let upperValue = collection.filter { $0 > input }.first!

            return (lowerValue, upperValue)
        }


        let (xLower, xUpper) = calculate(worldPos.x, widthSegments)
        let (zLower, zUpper) = calculate(worldPos.z, heightSegments)

        return (float3(xLower, 0, zLower), float3(xUpper, 0, zUpper))
    }
}
