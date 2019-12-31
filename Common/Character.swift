//
//  Character.swift
//  Highlands
//
//  Created by Scott Mehus on 12/19/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

class CharacterTorch: Prop {

    static let localPosition: SIMD3<Float> = [0.14, 0.85, -1.8]

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

    var debugBoundingBox: DebugBoundingBox?
    override var boundingBox: MDLAxisAlignedBoundingBox {
        didSet {
            debugBoundingBox = DebugBoundingBox(boundingBox: boundingBox)
        }
    }

    let meshes: [Mesh]
    var currentTime: Float = 0
    var samplerState: MTLSamplerState
    static var vertexDescriptor: MDLVertexDescriptor = MDLVertexDescriptor.defaultVertexDescriptor


    // Stuff I added \\


    // Not sure about this tho
//    var currentAnimation: AnimationClip?
//    var currentAnimationPlaying = false

    var shadowInstanceCount: Int = 0

    let heightCalculatePipelineState: MTLComputePipelineState
    let needsXRotationFix = true
    let heightBuffer: MTLBuffer

    let patches: [Patch]
    var currentPatch: Patch?
    var positionInPatch: SIMD3<Float>?

    init(name: String) {
        guard let assetURL = Bundle.main.url(forResource: name, withExtension: nil) else { fatalError() }

        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let asset = MDLAsset(url: assetURL,
                             vertexDescriptor: MDLVertexDescriptor.defaultVertexDescriptor,
                             bufferAllocator: allocator)

        asset.loadTextures()

        var mtkMeshes: [MTKMesh] = []
        let mdlMeshes = asset.childObjects(of: MDLMesh.self) as! [MDLMesh]
        _ = mdlMeshes.map { mdlMesh in
            mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed:
                MDLVertexAttributeTextureCoordinate,
                                    tangentAttributeNamed: MDLVertexAttributeTangent,
                                    bitangentAttributeNamed: MDLVertexAttributeBitangent)

            Character.vertexDescriptor = mdlMesh.vertexDescriptor
            mtkMeshes.append(try! MTKMesh(mesh: mdlMesh, device: Renderer.device))
        }

        meshes = zip(mdlMeshes, mtkMeshes).map {
            return Mesh(mdlMesh: $0.0,
                        mtkMesh: $0.1,
                        startTime: asset.startTime,
                        endTime: asset.endTime,
                        modelType: .character)
        }

        samplerState = Character.buildSamplerState()
        heightCalculatePipelineState = Character.buildComputePipelineState()

        heightBuffer = Renderer.device.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)!

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


    override var forwardVector: SIMD3<Float> {
        return normalize([sin(-rotation.z), 0, cos(-rotation.z)])
    }

    override func update(deltaTime: Float) {

        currentPatch = patch(for: position)
        positionInPatch = positionInPatch(patch: currentPatch)

        if position.y == 0 {
            let pointer = heightBuffer.contents().bindMemory(to: Float.self, capacity: 1)
            position.y = pointer.pointee
        }



        // Run / Update Animations
        currentTime += deltaTime
        for mesh in meshes {
            // TODO: - Make sure this is right?
            mesh.transform?.setCurrentTransform(at: deltaTime)
        }


        /* DEPRECATED WITH USDA
        guard let animation = currentAnimation, currentAnimationPlaying == true else {
            return
        }

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

         */

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

    func patch(for location: SIMD3<Float>) -> Patch? {
        let foundPatches = patches.filter { (patch) -> Bool in
            let horizontal = patch.topLeft.x < location.x && patch.topRight.x > location.x
            let vertical = patch.topLeft.z > location.z && patch.bottomLeft.z < location.z

            return horizontal && vertical
        }

//        print("**** patches found for position \(foundPatches.count)")
        guard let patch = foundPatches.first else { return nil }

        if let current = currentPatch, current != patch {
//            print("*** UPDATE CURRENT PATCH \(patch)")
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

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
//        renderEncoder.setFrontFacing(.clockwise)

        for mesh in meshes {

            var uniforms = vertex
            uniforms.modelMatrix = worldTransform * (mesh.transform?.currentTransform ?? float4x4.identity())
            uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

            renderEncoder.setFragmentSamplerState(samplerState, index: 0)

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            for (index, vertexBuffer) in mesh.mtkMesh.vertexBuffers.enumerated() {
              renderEncoder.setVertexBuffer(vertexBuffer.buffer,
                                            offset: 0, index: index)
            }

            for submesh in mesh.submeshes {
                renderEncoder.setRenderPipelineState(submesh.pipelineState)

                // Set the textures
                renderEncoder.setFragmentTexture(submesh.textures.baseColor, index: Int(BaseColorTexture.rawValue))
                renderEncoder.setFragmentTexture(submesh.textures.normal, index: Int(NormalTexture.rawValue))
                renderEncoder.setFragmentTexture(submesh.textures.roughness, index: Int(RoughnessTexture.rawValue))

                // Set Material
                var material = submesh.material
                renderEncoder.setFragmentBytes(&material,
                                               length: MemoryLayout<Material>.stride,
                                               index: Int(BufferIndexMaterials.rawValue))


                render(renderEncoder: renderEncoder, submesh: submesh)
            }

            if debugRenderBoundingBox {
                debugBoundingBox?.render(renderEncoder: renderEncoder, uniforms: uniforms)
            }
        }
    }

    func render(renderEncoder: MTLRenderCommandEncoder, submesh: Submesh) {
      let mtkSubmesh = submesh.mtkSubmesh
      renderEncoder.drawIndexedPrimitives(type: .triangle,
                                          indexCount: mtkSubmesh.indexCount,
                                          indexType: mtkSubmesh.indexType,
                                          indexBuffer: mtkSubmesh.indexBuffer.buffer,
                                          indexBufferOffset: mtkSubmesh.indexBuffer.offset)
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
//        guard let patchPosition = positionInPatch else { return }


//        var position = patchPosition
        var position = self.worldTransform.columns.3.xyz
        var terrainParams = terrain
        var uniforms = uniforms
        var index = 0

        computeEncoder.setComputePipelineState(heightCalculatePipelineState)
        computeEncoder.setBytes(&position, length: MemoryLayout<SIMD3<Float>>.size, index: 0)
        computeEncoder.setBuffer(heightBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&terrainParams, length: MemoryLayout<TerrainParams>.stride, index: 2)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 3)
        computeEncoder.setTexture(heightMapTexture, index: 0)
        computeEncoder.setBuffer(controlPointsBuffer, offset: 0, index: 4)
        computeEncoder.setBytes(&patch, length: MemoryLayout<Patch>.stride, index: 5)
        computeEncoder.setBytes(&index, length: MemoryLayout<Int>.size, index: 6)

        computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                            threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
    }

    func positionInPatch(patch: Patch?) -> SIMD3<Float>? {
        guard let patch = patch else { return nil }

        let worldPos = self.worldTransform.columns.3.xyz
        let x = (worldPos.x - patch.topLeft.x) / (patch.topRight.x - patch.topLeft.x);
        let z = (worldPos.z - patch.bottomLeft.z) / (patch.topLeft.z - patch.bottomLeft.z);

        let calculate: (Float) -> Float = { input in
            let value = [0.25, 0.5, 1.0].sorted { (first, second) -> Bool in
                return abs(input - first) < abs(input - second)
            }.first

            return value!
        }

        let final = SIMD3<Float>(calculate(x), 0, calculate(z))
        return final
    }
}
