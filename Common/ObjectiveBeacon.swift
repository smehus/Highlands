//
//  ObjectiveBeacon.swift
//  Highlands
//
//  Created by Scott Mehus on 6/7/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import MetalKit

final class ObjectiveBeacon: Node {

    private let mdlMesh: MDLMesh!
    private let mtkMesh: MTKMesh!
    private let pipelineState: MTLRenderPipelineState

    override init() {

        let allocator = MTKMeshBufferAllocator(
            device: Renderer.device
        )

        mdlMesh = MDLMesh(
            sphereWithExtent: [1, 1, 1],
            segments: [1, 1],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: allocator
        )

        mtkMesh = try! MTKMesh(mesh: mdlMesh, device: Renderer.device)

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = Renderer.library!.makeFunction(name: "objective_vertex")
        descriptor.fragmentFunction = Renderer.library!.makeFunction(name: "objective_fragment")
        descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        descriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mtkMesh.vertexDescriptor)

        pipelineState = try! Renderer.device.makeRenderPipelineState(descriptor: descriptor)

        super.init()
    }
}

extension ObjectiveBeacon: Renderable {
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
        var uniforms = vertex

        uniforms.modelMatrix = worldTransform
        uniforms.normalMatrix = float3x3(normalFrom4x4: worldTransform)

        // Depth stencil state

        // Pipelinestate
        renderEncoder.setRenderPipelineState(pipelineState)

        // uniforms
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms.rawValue))

        // Vertex buffer
        renderEncoder.setVertexBuffer(mtkMesh.vertexBuffers.first!.buffer, offset: 0, index: 0)

        // Textures
        renderEncoder.setFragmentTexture(TextureController.maskRenderPass.texture, index: 0)

        for submesh in mtkMesh.submeshes {
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset
            )
        }

    }

    func createTexturesBuffer() { }

}
