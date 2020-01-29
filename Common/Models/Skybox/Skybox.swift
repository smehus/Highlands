//
//  Skybox.swift
//  Highlands
//
//  Created by Scott Mehus on 1/9/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

import MetalKit

class Skybox {

    struct SkySettings {
        var turbidity: Float = 0.28
        var sunElevation: Float = 0.0
        var upperAtmosphereScattering: Float = 0.1
        var groundAlbedo: Float = 4
    }

    var skySettings = SkySettings()
    let mesh: MTKMesh
    var texture: MTLTexture?
    let pipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState?

    init(textureName: String?) {
        let allocator = MTKMeshBufferAllocator(device: RendererBlueprint.device)
        let cube = MDLMesh(boxWithExtent: [1, 1, 1],
                           segments: [1, 1, 1],
                           inwardNormals: true,
                           geometryType: .triangles,
                           allocator: allocator)

        do {
            mesh = try MTKMesh(mesh: cube, device: RendererBlueprint.device)
        } catch {
            fatalError("failed to create skybox mesh")
        }

        pipelineState = Skybox.buildPipelineState(vertexDescriptor: cube.vertexDescriptor)
        depthStencilState = Skybox.buildDepthStencilState()

        if let textureName = textureName {

        } else {
            texture = loadGeneratedSkyboxTexture(dimensions: [256, 256])
        }
    }

    func loadGeneratedSkyboxTexture(dimensions: int2) -> MTLTexture? {
        var texture: MTLTexture?
        let skyTexture = MDLSkyCubeTexture(name: "sky",
                                           channelEncoding: .uInt8,
                                           textureDimensions: dimensions,
                                           turbidity: skySettings.turbidity,
                                           sunElevation: skySettings.sunElevation,
                                           upperAtmosphereScattering: skySettings.upperAtmosphereScattering,
                                           groundAlbedo: skySettings.groundAlbedo)



        do {
            let textureLoader = MTKTextureLoader(device: RendererBlueprint.device)
            texture = try textureLoader.newTexture(texture: skyTexture, options: nil)
        } catch {
            print(error.localizedDescription)
        }

        return texture
    }

    private static func buildDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        return RendererBlueprint.device.makeDepthStencilState(descriptor: descriptor)
    }

    private static func buildPipelineState(vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = RendererBlueprint.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
//        descriptor.sampleCount = RendererBlueprint.sampleCount
        descriptor.vertexFunction = RendererBlueprint.library?.makeFunction(name: "vertexSkybox")
        descriptor.fragmentFunction = RendererBlueprint.library?.makeFunction(name: "fragmentSkybox")
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        do {
            return try RendererBlueprint.device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms) {
        renderEncoder.pushDebugGroup("Skybox")
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)

        var viewMatrix = uniforms.viewMatrix
        // zero out translation so skybox doesn't move
        viewMatrix.columns.3 = [0, 0, 0, 1]
        var viewProjectionMatrix = uniforms.projectionMatrix * viewMatrix
        renderEncoder.setVertexBytes(&viewProjectionMatrix, length: MemoryLayout<float4x4>.stride, index: 1)
        renderEncoder.setFragmentTexture(texture, index: Int(BufferIndexSkybox.rawValue))

        let submesh = mesh.submeshes[0]
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: submesh.indexBuffer.offset)

        renderEncoder.popDebugGroup()
    }
}
