//
//  Character.swift
//  Highlands
//
//  Created by Scott Mehus on 12/19/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

public class CharacterNode {
    var name: String = " "
    public var nodeIndex: Int = 0  //
    public var childIndices = [Int]()
    public var skin: GLTFSkin?
    public var jointName: String?
    public var mesh: GLTFMesh?
    public var rotationQuaternion = simd_quatf()
    public var scale = float3(1)
    public var translation = float3(0)
    public var matrix: float4x4?
    public var approximateBounds = ""
    public var inverseBindTransform = float4x4.identity()

    // generated
    public var parent: CharacterNode?
    public var children = [CharacterNode]()

    public var localTransform: float4x4 {
        if let matrix = matrix {
            return matrix
        }
        let T = float4x4(translation: translation)
        let R = float4x4(rotationQuaternion)
        let S = float4x4(scaling: scale)
        return T * R * S
    }

    var globalTransform: float4x4 {
        if let parent = parent {
            return parent.globalTransform * self.localTransform
        }
        return localTransform
    }
}

extension Character: Texturable { }

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

//    let buffers: [MTLBuffer]
//    let meshNodes: [GLTFNode]
    let animations: [GLTFAnimation]
    let rootNode: GLTFNode
    let asset: GLTFAsset
//    let textures: [String: MTLTexture]
    var currentTime: Float = 0
    var currentAnimation: GLTFAnimation?
    var currentAnimationPlaying = false
    var samplerState: MTLSamplerState
    var shadowInstanceCount: Int = 0
    let glRenderer = GLTFMTLRenderer(device: Renderer.device)

    init(name: String) {
        let url = Bundle.main.url(forResource: name, withExtension: "gltf")!
        let allocator = GLTFMTLBufferAllocator(device: Renderer.device)
        asset = GLTFAsset(url: url, bufferAllocator: allocator)

//        buffers = asset.buffers
        animations = asset.animations
        guard !asset.scenes.isEmpty else { fatalError() }

        // The nodes that contain skinning data which bind vertices to joints.
//        meshNodes = asset.defaultScene!.nodes.first!.children
//        nodes = asset.defaultScene!.nodes

        rootNode = asset.defaultScene!.nodes.first!
        samplerState = Character.buildSamplerState()

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

    override func update(deltaTime: Float) {
        guard let animation = currentAnimation, currentAnimationPlaying == true else {
            return
        }

        /*
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
 */
    }
}

extension Character: Renderable {
/*
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
 */
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
//        renderEncoder.setFrontFacing(.clockwise)

        for node in rootNode.children {
            guard let mesh = node.mesh else { continue }

//            if let skin = node.skin {
////                // FIXME: -- Need to figure out what this does and assign values
////                for (i, jointNode) in skin.jointNodes.enumerated() {
////                    skin.jointMatrixPalette[i] = node.globalTransform.inverse * jointNode.globalTransform * jointNode.inverseBindTransform
////                }
////
////                let length = MemoryLayout<float4x4>.stride * skin.jointMatrixPalette.count
////                let buffer = Renderer.device.makeBuffer(bytes: &skin.jointMatrixPalette, length: length, options: [])
////                renderEncoder.setVertexBuffer(buffer, offset: 0, index: 21)
//
//            }

            var uniforms = vertex
            uniforms.modelMatrix = worldTransform
            uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

            renderEncoder.setFragmentSamplerState(samplerState, index: 0)

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            for submesh in mesh.submeshes {
                guard let indexAcessor = submesh.indexAccessor else { fatalError() }

                if let skin = node.skin {
                    let buffer = Renderer.device.makeBuffer(length: skin.jointNodes.count * MemoryLayout<simd_float4x4>.size, options: .storageModeShared)
                    glRenderer.computeJoints(for: submesh, in: node, buffer: buffer!)
                    renderEncoder.setVertexBuffer(buffer!, offset: 0, index: 16)
                }


                let shaderBuilder = GLTFMTLShaderBuilder()
                /*
                 // create my own pipeline state
                let pipeline = shaderBuilder.renderPipelineState(for: submesh,
                                                                 lightingEnvironment: nil,
                                                                 colorPixelFormat: Renderer.colorPixelFormat,
                                                                 depthStencilPixelFormat: Renderer.depthPixelFormat,
                                                                 sampleCount: Int32(Renderer.sampleCount),
                                                                 device: Renderer.device)
                 */



//                let descriptor = shaderBuilder.vertexDescriptor(for: submesh)
                let pipeline = shaderBuilder.renderPipelineState(for: submesh,
                                                                 lightingEnvironment: nil,
                                                                 colorPixelFormat: Renderer.colorPixelFormat,
                                                                 depthStencilPixelFormat: Renderer.depthPixelFormat,
                                                                 sampleCount: Int32(Renderer.sampleCount),
                                                                 device: Renderer.device)
                renderEncoder.setRenderPipelineState(pipeline)

                // Set the actual texture image
                guard var material = submesh.material else { fatalError() }
                guard let image = material.baseColorTexture?.texture.image else { fatalError() }
                let texture = glRenderer.texture(for: image, preferSRGB: true)


                renderEncoder.setFragmentTexture(texture, index: Int(BaseColorTexture.rawValue))

                // Set Material - basically just the hard coded color

                renderEncoder.setFragmentBytes(&material,
                                               length: MemoryLayout<Material>.stride,
                                               index: Int(BufferIndexMaterials.rawValue))

                for (index, attribute) in submesh.vertexDescriptor.attributes.enumerated() {
                    guard !attribute.semantic.isEmpty else { continue }
                    guard let accessor = submesh.accessorsForAttributes[attribute.semantic] else { continue }
                    guard let bufferView = accessor.bufferView else { fatalError() }
                    guard let buffer = (bufferView.buffer as? GLTFMTLBuffer)?.buffer else { fatalError() }

                    renderEncoder.setVertexBuffer(buffer,
                                                  offset: accessor.offset + bufferView.offset,
                                                  index: index)
                }

                guard let indexBuffer = indexAcessor.bufferView?.buffer as? GLTFMTLBuffer else { fatalError() }
                let indexType = (indexAcessor.componentType == .dataTypeUShort) ? MTLIndexType.uint16 : MTLIndexType.uint32

                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: indexAcessor.count,
                                                    indexType: indexType,
                                                    indexBuffer: indexBuffer.buffer,
                                                    indexBufferOffset: indexAcessor.offset + indexAcessor.bufferView!.offset)
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
}

extension GLTFAsset {

    private func buildFunctionConstants() -> MTLFunctionConstantValues {

        var hasNormal = false
        var hasTangent = false
        var hasTexture = true


        let functionConstants = MTLFunctionConstantValues()
        functionConstants.setConstantValue(&hasTexture, type: .bool, index: 0)
        functionConstants.setConstantValue(&hasNormal, type: .bool, index: Int(Normal.rawValue))
        functionConstants.setConstantValue(&hasTangent, type: .bool, index: Int(Tangent.rawValue))
        return functionConstants
    }

    func createPipelineState(vertexDescriptor: MTLVertexDescriptor) -> MTLRenderPipelineState {
        let functionConstants = buildFunctionConstants()
        let pipelineState: MTLRenderPipelineState
        do {
            let library = Renderer.device.makeDefaultLibrary()
            let vertexFunction = try library?.makeFunction(name: "character_vertex_main", constantValues: functionConstants)
            let fragmentFunction = try library?.makeFunction(name: "character_fragment_main", constantValues: functionConstants)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.vertexDescriptor = vertexDescriptor
            descriptor.depthAttachmentPixelFormat = .depth32Float
            descriptor.sampleCount = Renderer.sampleCount
            try pipelineState = Renderer.device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }
}
