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
    private let mdlMesh: MDLMesh
    private var pipelineState: MTLRenderPipelineState
    private var waterNormalTexture: MTLTexture
    private var timer: Float = 0
    private let refractionRenderPass: RenderPass
    private let reflectionRenderPass: RenderPass
    private let depthStencilState: MTLDepthStencilState
    private let reflectionCamera = Camera()


    init(size: Float) {
        do {
            let plane = Primitive.makePlane(device: RendererBlueprint.device, size: size)
            mdlMesh = plane

            mesh = try MTKMesh(mesh: plane, device: RendererBlueprint.device)
            waterNormalTexture = try Submesh.loadTexture(imageName: "normal-water.png")!



            let library = RendererBlueprint.device.makeDefaultLibrary()!
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertex_water")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_water")
            descriptor.colorAttachments[0].pixelFormat = RendererBlueprint.colorPixelFormat
            descriptor.depthAttachmentPixelFormat = .depth32Float
            descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
            pipelineState = try RendererBlueprint.device.makeRenderPipelineState(descriptor: descriptor)

            reflectionRenderPass = RenderPass(name: "reflection", size: RendererBlueprint.drawableSize)
            refractionRenderPass = RenderPass(name: "refraction", size: RendererBlueprint.drawableSize)

            let stencilDescriptor = MTLDepthStencilDescriptor()
            stencilDescriptor.depthCompareFunction = .less
            stencilDescriptor.isDepthWriteEnabled = true
            depthStencilState = RendererBlueprint.device.makeDepthStencilState(descriptor: stencilDescriptor)!

        } catch {
            fatalError(error.localizedDescription)
        }

        super.init()
    }
}

extension Water: Renderable {

    func renderToTarget(with commandBuffer: MTLCommandBuffer, camera: Camera, uniforms: Uniforms, renderables: [Renderable]) {
        var uniforms = uniforms

        // Reflection
        let reflectEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: reflectionRenderPass.descriptor)!
        reflectEncoder.setDepthStencilState(depthStencilState)

        reflectionCamera.position = camera.position
        reflectionCamera.position.y = -camera.position.y
        reflectionCamera.rotation.x = -camera.rotation.x
        uniforms.viewMatrix = reflectionCamera.viewMatrix

        for renderable in renderables {
            reflectEncoder.pushDebugGroup("Water Refract \(renderable.name)")
            renderable.render(renderEncoder: reflectEncoder, uniforms: uniforms)
            reflectEncoder.popDebugGroup()
        }

        reflectEncoder.endEncoding()

        
        // Refraction
        uniforms.viewMatrix = camera.viewMatrix
        let refractEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: refractionRenderPass.descriptor)!
        refractEncoder.setDepthStencilState(depthStencilState)

        for renderable in renderables {
            refractEncoder.pushDebugGroup("Water Refract \(renderable.name)")
            renderable.render(renderEncoder: refractEncoder, uniforms: uniforms)
            refractEncoder.popDebugGroup()
        }

        refractEncoder.endEncoding()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        reflectionRenderPass.updateTextures(size: size)
        refractionRenderPass.updateTextures(size: size)
    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
        renderEncoder.pushDebugGroup("Water")

        timer += 0.0001

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers.first!.buffer, offset: 0, index: 0)

        var uniforms = vertex
        uniforms.modelMatrix = worldTransform
        uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

        renderEncoder.setFragmentTexture(reflectionRenderPass.texture, index: 0)
        renderEncoder.setFragmentTexture(refractionRenderPass.texture, index: 1)
        renderEncoder.setFragmentTexture(waterNormalTexture, index: 2)

        renderEncoder.setFragmentBytes(&timer, length: MemoryLayout<Float>.size, index: 3)
        for (index, submesh) in mesh.submeshes.enumerated() {

            // Not a great way to do this
            let mdlSubmesh = mdlMesh.submeshes?[index] as! MDLSubmesh
            var material = Material(material: mdlSubmesh.material)
            renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: Int(BufferIndexMaterials.rawValue))

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




