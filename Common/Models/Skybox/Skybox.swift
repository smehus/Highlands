//
//  Skybox.swift
//  Highlands
//
//  Created by Scott Mehus on 1/9/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

import MetalKit

class Skybox {

    let mesh: MTKMesh
    var texture: MTLTexture?
    let pipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState?

    init(textureName: String) {
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let cube = MDLMesh(boxWithExtent: [1, 1, 1],
                           segments: [1, 1, 1],
                           inwardNormals: true,
                           geometryType: .triangles,
                           allocator: allocator)

        do {
            mesh = try MTKMesh(mesh: cube, device: Renderer.device)
        } catch {
            fatalError("failed to create skybox mesh")
        }

        pipelineState = Skybox.buildPipelineState(vertexDescriptor: cube.vertexDescriptor)
        depthStencilState = Skybox.buildDepthStencilState()
    }

    private static func buildDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        return Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }

    private static func buildPipelineState(vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = Renderer.library?.makeFunction(name: "vertexSkybox")
        descriptor.fragmentFunction = Renderer.library?.makeFunction(name: "fragmentSkybox")
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        do {
            return try Renderer.device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms) {

    }
}
