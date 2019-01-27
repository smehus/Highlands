
import MetalKit

final class Renderer: NSObject {

    static let sampleCount = 1

    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var colorPixelFormat: MTLPixelFormat!
    static var library: MTLLibrary?

    var scene: Scene?

    private var depthStencilState: MTLDepthStencilState!

    var albedoTexture: MTLTexture!
    var normalTexture: MTLTexture!
    var positionTexture: MTLTexture!
    var depthTexture: MTLTexture!

    
    var gBufferRenderPassDescriptor: MTLRenderPassDescriptor!

    lazy var lightPipelineState: MTLRenderPipelineState = {
        return buildLightPipelineState()
    }()

    
    var shadowTexture: MTLTexture!
    let shadowRenderPassDescriptor = MTLRenderPassDescriptor()

    var compositionPipelineState: MTLRenderPipelineState!
    var quadVerticesBuffer: MTLBuffer!
    var quadTexCoordsBuffer: MTLBuffer!

    let quadVertices: [Float] = [
        -1.0,  1.0,
        1.0, -1.0,
        -1.0, -1.0,
        -1.0,  1.0,
        1.0, 1.0,
        1.0, -1.0, ]
    let quadTexCoords: [Float] = [
        0.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0
    ]

    init(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }

        metalView.sampleCount = Renderer.sampleCount
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.device = device
        Renderer.device = device
        Renderer.commandQueue = device.makeCommandQueue()!
        Renderer.colorPixelFormat = metalView.colorPixelFormat
        Renderer.library = device.makeDefaultLibrary()

        super.init()
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.5,
                                             blue: 1, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)

        buildDepthStencilState()
        buildShadowTexture(size: metalView.drawableSize)


        quadVerticesBuffer = Renderer.device.makeBuffer(bytes: quadVertices,
                                                        length: MemoryLayout<Float>.size * quadVertices.count,
                                                        options: [])
        quadVerticesBuffer.label = "Quad vertices"
        quadTexCoordsBuffer = Renderer.device.makeBuffer(bytes: quadTexCoords,
                                                         length: MemoryLayout<Float>.size * quadTexCoords.count,
                                                         options: [])
        quadTexCoordsBuffer.label = "Quad texCoords"

        buildCompositionPipelineState()
    }

    func buildShadowTexture(size: CGSize) {
        shadowTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Shadow")
        shadowRenderPassDescriptor.setUpDepthAttachment(texture: shadowTexture)
    }

    func buildDepthStencilState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depthStencilState = Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }

    func buildGBufferRenderPassDescriptor(size: CGSize) {
        gBufferRenderPassDescriptor = MTLRenderPassDescriptor()
        buildGbufferTextures(size: size)
        let textures: [MTLTexture] = [albedoTexture, normalTexture, positionTexture]

        for (position, texture) in textures.enumerated() {
            gBufferRenderPassDescriptor.setUpColorAttachment(position: position, texture: texture)
        }

        gBufferRenderPassDescriptor.setUpDepthAttachment(texture: depthTexture)
    }


    func buildGbufferTextures(size: CGSize) {
        albedoTexture = buildTexture(pixelFormat: .bgra8Unorm, size: size, label: "Albedo texture")
        normalTexture = buildTexture(pixelFormat: .rgba16Float, size: size, label: "Normal texture")
        positionTexture = buildTexture(pixelFormat: .rgba16Float, size: size, label: "Position texture")
        depthTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Depth texture")
    }

    func buildCompositionPipelineState() {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.label = "Composition state"

        descriptor.vertexFunction = Renderer.library!.makeFunction( name: "compositionVert")
        descriptor.fragmentFunction = Renderer.library!.makeFunction( name: "compositionFrag")
        do {
            compositionPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        scene?.sceneSizeWillChange(to: size)
        buildShadowTexture(size: size)
        buildGBufferRenderPassDescriptor(size: size)
    }

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let scene = scene
        else {
            return
        }

        let deltaTime = 1 / Float(view.preferredFramesPerSecond)
        scene.update(deltaTime: deltaTime)

        let previousUniforms = scene.uniforms
        // Shadow pass
        guard let shadowEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptor) else {
            return
        }

        renderShadowPass(renderEncoder: shadowEncoder, view: view)

        scene.uniforms.viewMatrix = previousUniforms.viewMatrix
        scene.uniforms.projectionMatrix = previousUniforms.projectionMatrix


        /// **** MAIN RENDER PASS *** \\\\

//        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
//        renderEncoder.pushDebugGroup("Main pass")
//        renderEncoder.label = "Main encoder"
//        renderEncoder.setDepthStencilState(depthStencilState)

        // Reset uniforms so projection is correct
        // GOOOOOOD LOORD i'm totally resetting the shadow matrix here
        // goodddddddd damniiitttttt
//        scene.uniforms = previousUniforms
//        scene.uniforms.modelMatrix = previousUniforms.modelMatrix
//        scene.uniforms.normalMatrix = previousUniforms.normalMatrix
        scene.uniforms.viewMatrix = previousUniforms.viewMatrix
        scene.uniforms.projectionMatrix = previousUniforms.projectionMatrix

//        renderEncoder.setFragmentTexture(shadowTexture, index: Int(ShadowTexture.rawValue))
//
//        for renderable in scene.renderables {
//            renderEncoder.pushDebugGroup(renderable.name)
//            renderable.render(renderEncoder: renderEncoder, uniforms: scene.uniforms)
//            renderEncoder.popDebugGroup()
//        }
//
////        scene.skybox?.render(renderEncoder: renderEncoder, uniforms: scene.uniforms)
//
//        renderEncoder.endEncoding()
//        renderEncoder.popDebugGroup()

        /// **** MAIN RENDER PASS  ENDDD *** \\\\

        // G-Buffer
        guard let gBufferEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: gBufferRenderPassDescriptor) else {
            return
        }

        renderGbufferPass(renderEncoder: gBufferEncoder)



        // Composition!!

        guard let compositionEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        renderCompositionPass(renderEncoder: compositionEncoder)

        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func renderShadowPass(renderEncoder: MTLRenderCommandEncoder, view: MTKView) {
        guard let scene = scene else { return }
        renderEncoder.pushDebugGroup("Shadow pass")
        renderEncoder.label = "Shadow encoder"
        renderEncoder.setCullMode(.none)
        renderEncoder.setDepthStencilState(depthStencilState)

        renderEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)

        let sunlight = scene.lights.first!

        let rect = Rectangle(left: -20, right: 20, top: 20, bottom: -20)
        scene.uniforms.projectionMatrix = float4x4(orthographic: rect, near: 0.1, far: 16)

        let position: float3 = [-sunlight.position.x, -sunlight.position.y, -sunlight.position.z]
        let center: float3 = [0, 0, 0]
        let lookAt = float4x4(eye: position, center: center, up: [0,1,0])

        scene.uniforms.viewMatrix = /*float4x4(translation: [0, 0, 7]) **/ lookAt
        scene.uniforms.shadowMatrix = scene.uniforms.projectionMatrix * scene.uniforms.viewMatrix

        for renderable in scene.renderables {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.renderShadow(renderEncoder: renderEncoder, uniforms: scene.uniforms)
            renderEncoder.popDebugGroup()
        }

        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }

    func renderGbufferPass(renderEncoder: MTLRenderCommandEncoder) {
        guard let scene = scene else { fatalError() }
        renderEncoder.pushDebugGroup("Gbuffer pass")
        renderEncoder.label = "Gbuffer encoder"

        renderEncoder.setDepthStencilState(depthStencilState)

        var fragmentUniforms = FragmentUniforms()
        fragmentUniforms.cameraPosition = scene.camera.position
        fragmentUniforms.lightCount = UInt32(scene.lights.count)
        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: Int(BufferIndexFragmentUniforms.rawValue))


        renderEncoder.setFragmentTexture(shadowTexture, index: Int(ShadowTexture.rawValue))

        for renderable in scene.renderables {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.renderGBuffer(renderEncoder: renderEncoder, uniforms: scene.uniforms)
            renderEncoder.popDebugGroup()
        }


        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }

    func renderCompositionPass(renderEncoder: MTLRenderCommandEncoder) {
        guard let scene = scene else { return }
        renderEncoder.pushDebugGroup("Composition pass")
        renderEncoder.label = "Composition encoder"

        renderEncoder.setRenderPipelineState(compositionPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)

        renderEncoder.setVertexBuffer(quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(albedoTexture, index: 0)
        renderEncoder.setFragmentTexture(normalTexture, index: 1)
        renderEncoder.setFragmentTexture(positionTexture, index: 2)

        var fragmentUniforms = FragmentUniforms()
        fragmentUniforms.cameraPosition = scene.camera.position
        fragmentUniforms.lightCount = UInt32(scene.lights.count)

        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: Int(BufferIndexFragmentUniforms.rawValue))


        renderEncoder.setFragmentBytes(&scene.lights,
                                       length: MemoryLayout<Light>.stride * scene.lights.count,
                                       index: Int(BufferIndexLights.rawValue))

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)

        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }


    private func drawDebug(encoder: MTLRenderCommandEncoder) {
        debugLights(renderEncoder: encoder, lightType: Pointlight)
    }
}

private extension Renderer {
    func buildTexture(pixelFormat: MTLPixelFormat, size: CGSize, label: String) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false)

        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private

        guard let texture = Renderer.device.makeTexture(descriptor: descriptor) else {
            fatalError()
        }

        texture.label = "\(label) texture"
        return texture
    }
}

// Renderers to a texture off screen
private extension MTLRenderPassDescriptor {
    func setUpDepthAttachment(texture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        depthAttachment.clearDepth = 1
    }

    func setUpColorAttachment(position: Int, texture: MTLTexture) {
        let attachment: MTLRenderPassColorAttachmentDescriptor = colorAttachments[position]
        attachment.texture = texture
        attachment.loadAction = .clear
        attachment.storeAction = .store
        attachment.clearColor = MTLClearColorMake(0.73, 0.92, 1, 1)
    }
}

