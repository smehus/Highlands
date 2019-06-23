//
//  Water.swift
//  Highlands
//
//  Created by Scott Mehus on 6/23/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

import Foundation
import MetalKit

class Water: Node {

    private let mesh: MTKMesh
    private var pipelineState: MTLRenderPipelineState

    init(size: Float) {
        do {
            let plane = Primitive.makePlane(device: Renderer.device, size: size)
            mesh = try MTKMesh(mesh: plane, device: Renderer.device)

            let library = Renderer.device.makeDefaultLibrary()!
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertex_water")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_water")
            descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
            descriptor.depthAttachmentPixelFormat = Renderer.depthPixelFormat
            descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
            pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }

        super.init()
    }
}

extension Water: Renderable {
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
        renderEncoder.pushDebugGroup("Water")

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers.first!.buffer, offset: 0, index: 0)

        var uniforms = vertex
        uniforms.modelMatrix = worldTransform
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }

        renderEncoder.popDebugGroup()
    }

    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, startingIndex: Int) {

    }
}




