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

private extension Dictionary where Key == String, Value == AnimationClip {
    subscript(_ animation: CharacterAnimation) -> AnimationClip {
        get {
            return self[animation.rawValue]!
        }
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

    private let animations: [String: AnimationClip]

    // Stuff I added \\

    var currentAnimation: CharacterAnimation = .idle
//    var currentAnimationPlaying = false

    var shadowInstanceCount: Int = 0
    var currentlyColliding = false {
        didSet {
            if currentlyColliding {
                set(animation: .pushing)
            }
        }
    }

    let heightCalculatePipelineState: MTLComputePipelineState
    let needsXRotationFix = true
    let heightBuffer: MTLBuffer

    var patches: [Patch]?
    var currentPatch: Patch?
    var positionInPatch: SIMD3<Float>?
    weak var currentTile: TileScene? {
        didSet {
            guard let tile = currentTile else { return }

            patches = tile.terrain.terrainPatches.1
        }
    }


    let boundingMask: MTKMesh
    let stencilPipelineState: MTLRenderPipelineState
    var maskPipeline: MTLRenderPipelineState

    init(name: String) {
        guard let assetURL = Bundle.main.url(forResource: name, withExtension: "usdz") else { fatalError() }

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

        let assetAnimations = asset.animations.objects.compactMap {
            $0 as? MDLPackedJointAnimation
        }

        let animations = Dictionary(uniqueKeysWithValues: assetAnimations.map {
            ($0.name, AnimationComponent.load(animation: $0))
        })

        self.animations = animations

        animations.forEach {
            print("*** ANIMATION \($0.key)")
        }

        samplerState = Character.buildSamplerState()
        heightCalculatePipelineState = Character.buildComputePipelineState()

        heightBuffer = Renderer.device.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)!

        let maskAllocator = MTKMeshBufferAllocator(device: Renderer.device)
        let mdlMask = MDLMesh.newEllipsoid(withRadii: [1.5, 0, 0.7], radialSegments: 40, verticalSegments: 1, geometryType: .triangles, inwardNormals: false, hemisphere: true, allocator: maskAllocator)
        boundingMask = try! MTKMesh(mesh: mdlMask, device: Renderer.device)

        let stencilPipelineDescriptor = MTLRenderPipelineDescriptor()
        stencilPipelineDescriptor.vertexFunction = Renderer.library!.makeFunction(name: "stencil_vertex")
        stencilPipelineDescriptor.fragmentFunction = nil
        stencilPipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        stencilPipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(boundingMask.vertexDescriptor)
        stencilPipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        stencilPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8

        stencilPipelineState = try! Renderer.device.makeRenderPipelineState(descriptor: stencilPipelineDescriptor)

        let maskPipelineDescriptor = MTLRenderPipelineDescriptor()
        maskPipelineDescriptor.vertexFunction = Renderer.library!.makeFunction(name: "stencil_vertex")!
        maskPipelineDescriptor.fragmentFunction = Renderer.library!.makeFunction(name: "fragment_mask")!
        maskPipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        maskPipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(boundingMask.vertexDescriptor)
        maskPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        maskPipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8

        maskPipeline = try! Renderer.device.makeRenderPipelineState(descriptor: maskPipelineDescriptor)

        super.init()
        self.name = name
    }

    private static func buildSamplerState() -> MTLSamplerState {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.mipFilter = .linear
//         TODO: I don't know why this is crashing me....
        descriptor.maxAnisotropy = 8
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

        let previousYPosition = Float(position.y)
        if position.y == 0 {
            let pointer = heightBuffer.contents().bindMemory(to: Float.self, capacity: 1)
            position.y = pointer.pointee
        }


        // Run / Update Animations
        currentTime += deltaTime

//        You're using the first animation for simplicity. The starter code for the following chapter will refactor the animation code so that you can send a named animation to the model.


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

        for mesh in meshes {
//            if var animation = currentAnimation {

            if currentAnimation == .walking {
                let uphill = ((position.y - previousYPosition) * 100) > 8.0
                if uphill {
                    currentAnimation = .wheelbarrow
                } else {
                    currentAnimation = .walking
                }
            }

            mesh.skeleton?.updatePose(animationClip: animations[currentAnimation], at: currentTime)
            mesh.transform?.currentTransform = .identity()
//            } else {
//                mesh.transform?.setCurrentTransform(at: currentTime)
//            }
        }


        // Doesn't do anything now?
//        if let tile = currentTile {
//            position.y += tile.position.y
//        }
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
        guard let tilePatches = patches else { return nil }

//        tilePatches.forEach({ print("*** \($0)") })
        let foundPatches = tilePatches.filter { (patch) -> Bool in
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

extension Character: Renderable {


    /// This works because the character is added to the scene rather than the TileScene.
    /// The game scene calls this in super.setup
    func createTexturesBuffer() {
        for mesh in meshes {
            for submesh in mesh.submeshes {
                submesh.createTexturesBuffer()
            }
        }
    }

    func renderStencilBuffer(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms) {
        var uniforms = uniforms

        // Used to remove water around the player - but right now not using the stencil buffer anymore.
        // Using rendered traget as mask
        return
        var transform = Transform()
        transform.position = position
        transform.position.x -= 1
//        transform.rotation = [0, 0, radians(fromDegrees: -90)]

        uniforms.modelMatrix = transform.modelMatrix

        renderEncoder.setRenderPipelineState(stencilPipelineState)
        renderEncoder.setVertexBuffer(boundingMask.vertexBuffers.first!.buffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms.rawValue))

        boundingMask.submeshes.forEach { (submesh) in
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
//        renderEncoder.setFrontFacing(.clockwise)

        for mesh in meshes {

            if let paletteBuffer = mesh.skeleton?.jointMatrixPaletteBuffer {
              renderEncoder.setVertexBuffer(paletteBuffer, offset: 0, index: 22)
            }

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
                // USING HEAP IN RENDERER INSTEAD
                // but still using the texturesBuffer?
//                if let baseColorIndex = submesh.baseColorIndex {
//                    renderEncoder.useResource(TextureController.textures[baseColorIndex].texture, usage: .read)
//                }
//
//                if let normalIndex = submesh.normalIndex {
//                    renderEncoder.useResource(TextureController.textures[normalIndex].texture, usage: .read)
//                }

//                if let roughnessTexture = submesh.textures.roughness {
//                    renderEncoder.useResource(roughnessTexture, usage: .read)
//                }

                renderEncoder.setFragmentBuffer(submesh.texturesBuffer, offset: 0, index: Int(BufferIndexTextures.rawValue))

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
                         terrainParams: TerrainParams,
                         uniforms: Uniforms,
                         controlPointsBuffer: MTLBuffer?) {


        guard var patch = currentPatch else { return }
//        guard let patchPosition = positionInPatch else { return }


//        var position = patchPosition
        var position = self.worldTransform.columns.3.xyz
        var terrainParams = terrainParams
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

extension Character {
    func render(renderEncoder: MTLRenderCommandEncoder,
                uniforms: Uniforms,
                fragmentUniforms fragment: FragmentUniforms) {

        var fragmentUniforms = fragment
        fragmentUniforms.tiling = 1
        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: Int(BufferIndexFragmentUniforms.rawValue))

        render(renderEncoder: renderEncoder, uniforms: uniforms)
    }
}


enum CharacterAnimation: String {
    case idle = "/walking_boy_all/Animations/idle"
    case walking = "/walking_boy_all/Animations/walking"
    case pushing = "/walking_boy_all/Animations/push"
    case wheelbarrow = "/walking_boy_all/Animations/wheelbarrow"
}

extension Character {

    func set(animation: CharacterAnimation) {
        currentAnimation = animation
    }
}

