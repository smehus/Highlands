//
//  Renderer.swift
//  Highlands
//
//  Created by Scott Mehus on 12/5/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

final class Renderer: NSObject {

    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var library: MTLLibrary!
    static var colorPixelFormat: MTLPixelFormat!

    lazy var camera: Camera = {
        let camera = Camera()
        camera.position = [0, 2, -6]
        return camera
    }()

    private var fragmentUniforms = FragmentUniforms()
    private var uniforms = Uniforms()
    private var depthStencilState: MTLDepthStencilState!

    private var models = [Model]()
    private lazy var lights: [Light] = {
        return lighting()
    }()

    init(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError()
        }

        metalView.device = device
        metalView.depthStencilPixelFormat = .depth32Float
        
        Renderer.commandQueue = device.makeCommandQueue()!
        Renderer.device = device
        Renderer.colorPixelFormat = metalView.colorPixelFormat
        Renderer.library = device.makeDefaultLibrary()

        super.init()

        metalView.clearColor = MTLClearColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)


        buildDepthStencilState()


        // models
        do {
            let model = try Model(name: "cottage1")
            model.position = [0, 0, 0]
            model.rotation = [0, radians(fromDegrees: 45), 0]
            models.append(model)
        } catch {
            fatalError(error.localizedDescription)
        }

        fragmentUniforms.lightCount = UInt32(lights.count)
    }

    private func buildDepthStencilState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depthStencilState = Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        camera.aspect = Float(view.bounds.width)/Float(view.bounds.height)
    }

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor else { return }
        guard let commandBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        renderEncoder.setDepthStencilState(depthStencilState)

        fragmentUniforms.cameraPosition = camera.position
        uniforms.projectionMatrix = camera.projectionMatrix
        uniforms.viewMatrix = camera.viewMatrix

        renderEncoder.setFragmentBytes(&lights, length: MemoryLayout<Light>.stride * lights.count, index: Int(BufferIndexLights.rawValue))

        for model in models {
            uniforms.normalMatrix = float3x3(normalFrom4x4: model.modelMatrix)
            uniforms.modelMatrix = model.modelMatrix

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            fragmentUniforms.tiling = model.tiling
            renderEncoder.setFragmentSamplerState(model.samplerState, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: Int(BufferIndexFragmentUniforms.rawValue))


            for (index, vertexBuffer) in model.mesh.vertexBuffers.enumerated() {
                renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, index: index)
            }

            for modelSubmesh in model.submeshes {
                renderEncoder.setRenderPipelineState(modelSubmesh.pipelineState)

                renderEncoder.setFragmentTexture(modelSubmesh.textures.baseColor, index: Int(BaseColorTexture.rawValue))
                renderEncoder.setFragmentTexture(modelSubmesh.textures.normal, index: Int(NormalTexture.rawValue))

                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: modelSubmesh.submesh.indexCount,
                                                    indexType: modelSubmesh.submesh.indexType,
                                                    indexBuffer: modelSubmesh.submesh.indexBuffer.buffer,
                                                    indexBufferOffset: modelSubmesh.submesh.indexBuffer.offset)
            }
        }

        renderEncoder.endEncoding()

        guard let drawable = view.currentDrawable else { fatalError() }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
