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
        camera.position = [0, 1.2, -4]
        return camera
    }()

    lazy var sunlight: Light = {
        var light = buildDefaultLight()
        light.position = [1, 2, -2]
        return light
    }()

    lazy var ambientLight: Light = {
        var light = buildDefaultLight()
        light.color = [0.5, 1, 0]
        light.intensity = 0.3
        light.type = Ambientlight
        return light
    }()

    lazy var redLight: Light = {
        var light = buildDefaultLight()
        light.position = [-0, 0.5, -0.5]
        light.color = [1, 0, 0]
        light.attenuation = float3(1, 3, 4)
        light.type = Pointlight
        return light
    }()

    lazy var spotlight: Light = {
        var light = buildDefaultLight()
        light.position = [0.4, 0.8, 1]
        light.color = [1, 0, 1]
        light.attenuation = float3(1, 0.5, 0)
        light.type = Spotlight
        light.coneAngle = radians(fromDegrees: 40)
        light.coneDirection = [-2, 0, -1.5]
        light.coneAttenuation = 12
        return light
    }()

    private var fragmentUniforms = FragmentUniforms()
    private var uniforms = Uniforms()
    private var depthStencilState: MTLDepthStencilState!

    private var models = [Model]()
    private var lights: [Light] = []

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


        let house = Model(name: "lowpoly-house")
        house.position = [0, 0, 0]
        house.rotation = [0, radians(fromDegrees: 45), 0]
        models.append(house)

        let ground = Model(name: "plane")
        ground.scale = [40, 40, 40]
        ground.tiling = 16
        models.append(ground)


        lights.append(sunlight)
        fragmentUniforms.lightCount = UInt32(lights.count)
    }

    private func buildDefaultLight() -> Light {
        var light = Light()
        light.position = [0, 0, 0]
        light.color = [1, 1, 1]
        light.specularColor = [0.6, 0.6, 0.6]
        light.intensity = 1
        light.attenuation = float3(1, 0, 0)
        light.type = Sunlight
        return light
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

            renderEncoder.setVertexBuffer(model.vertexBuffer, offset: 0, index: Int(BufferIndexVertices.rawValue))

            for modelSubmesh in model.submeshes {
                renderEncoder.setRenderPipelineState(modelSubmesh.pipelineState)
                renderEncoder.setFragmentTexture(modelSubmesh.textures.baseColor, index: Int(BaseColorTexture.rawValue))

                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: modelSubmesh.submesh.indexCount,
                                                    indexType: modelSubmesh.submesh.indexType,
                                                    indexBuffer: modelSubmesh.submesh.indexBuffer.buffer,
                                                    indexBufferOffset: modelSubmesh.submesh.indexBuffer.offset)
            }
        }

        renderEncoder.endEncoding()

        guard let drawable = view.currentDrawable else { return }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
