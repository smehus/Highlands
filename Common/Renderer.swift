//
//  Renderer.swift
//  Highlands
//
//  Created by Scott Mehus on 12/5/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

protocol Renderable {
    var name: String { get }
    func update(deltaTime: Float)
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, fragmentUniforms: FragmentUniforms)
}

final class Renderer: NSObject {

    // Chapter Variables
    var currentTime: Float = 0
    var maxVelocity: Float = 0
    var ballVelocity: Float = 0

    // Base Variables
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var library: MTLLibrary!
    static var colorPixelFormat: MTLPixelFormat!

    lazy var camera: Camera = {
        let camera = Camera()
        camera.position = [0, 1, -3]
        return camera
    }()

    private var fragmentUniforms = FragmentUniforms()
    private var uniforms = Uniforms()
    private var depthStencilState: MTLDepthStencilState!

    private var models = [Renderable]()
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

        metalView.clearColor = MTLClearColor(red: 0.43, green: 0.47,
                                             blue: 0.5, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)


        buildDepthStencilState()

        let skeleton = Character(name: "scene")
        skeleton.rotation = float3(85, 0, 0)
        models.append(skeleton)

        let ground = Prop(name: "ground")
        ground.scale = [10, 10, 10]
        models.append(ground)


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

        // *** Chapter Work
        let deltaTime = 1 / Float(view.preferredFramesPerSecond)
        update(deltaTime: deltaTime)


        // ***** End

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

    func update(deltaTime: Float) {
        for model in models {
            model.update(deltaTime: deltaTime)
        }
    }
}
