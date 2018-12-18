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
        camera.position = [0, 0, -3]
        return camera
    }()

    private var fragmentUniforms = FragmentUniforms()
    private var uniforms = Uniforms()
    private var depthStencilState: MTLDepthStencilState!

    private var models = [Prop]()
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
            let model = try Prop(name: "cottage1")
            model.position = [0, 0, 0]
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
            model.render(renderEncoder: renderEncoder, uniforms: uniforms, fragmentUniforms: fragmentUniforms)
        }

        renderEncoder.endEncoding()

        guard let drawable = view.currentDrawable else { fatalError() }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
