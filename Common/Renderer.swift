
import MetalKit

final class Renderer: NSObject {

    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var colorPixelFormat: MTLPixelFormat!
    static var library: MTLLibrary?

    var scene: Scene?

    private var depthStencilState: MTLDepthStencilState!

    lazy var lightPipelineState: MTLRenderPipelineState = {
        return buildLightPipelineState()
    }()

    var shadowPipelineState: MTLRenderPipelineState!
    var shadowTexture: MTLTexture!
    let shadowRenderPassDescriptor = MTLRenderPassDescriptor()

    init(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }

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
        buildShadowPipelineState()
    }

    func buildShadowPipelineState() {

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = Renderer.library!.makeFunction( name: "vertex_depth")
        pipelineDescriptor.fragmentFunction = nil
        pipelineDescriptor.colorAttachments[0].pixelFormat = .invalid
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(Prop.defaultVertexDescriptor)
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            shadowPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

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
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        scene?.sceneSizeWillChange(to: size)
        buildShadowTexture(size: size)
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

        renderShadowPass(renderEncoder: shadowEncoder)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return 
        }

        renderEncoder.setDepthStencilState(depthStencilState)

        var fragmentUniforms = FragmentUniforms()
        fragmentUniforms.cameraPosition = scene.camera.position
        fragmentUniforms.lightCount = UInt32(scene.lights.count)

        scene.uniforms = previousUniforms

        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: Int(BufferIndexFragmentUniforms.rawValue))

        
        renderEncoder.setFragmentBytes(&scene.lights,
                                       length: MemoryLayout<Light>.stride * scene.lights.count,
                                       index: Int(BufferIndexLights.rawValue))

        for renderable in scene.renderables {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.render(renderEncoder: renderEncoder, uniforms: scene.uniforms, pipeline: nil)
            renderEncoder.popDebugGroup()
        }

        scene.skybox?.render(renderEncoder: renderEncoder, uniforms: scene.uniforms)

//        drawDebug(encoder: renderEncoder)

        renderEncoder.endEncoding()

        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func renderShadowPass(renderEncoder: MTLRenderCommandEncoder) {
        guard let scene = scene else { return }
        renderEncoder.pushDebugGroup("Shadow pass")
        renderEncoder.label = "Shadow encoder"
        renderEncoder.setCullMode(.none)
        renderEncoder.setDepthStencilState(depthStencilState)

        renderEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)

        let rect = Rectangle(left: -8, right: 8, top: 8, bottom: -8)
        scene.uniforms.projectionMatrix = float4x4(orthographic: rect, near: 0.1, far: 16)

        let sunlight = scene.lights.first!
        let position: float3 = [-sunlight.position.x, -sunlight.position.y, -sunlight.position.z]

        let center: float3 = [0, 0, 0]
        let lookAt = float4x4(eye: position, center: center, up: [0,1,0])

        scene.uniforms.viewMatrix = float4x4(translation: [0, 0, 7]) * lookAt
        scene.uniforms.shadowMatrix = scene.uniforms.projectionMatrix * scene.uniforms.viewMatrix

//        renderEncoder.setRenderPipelineState(shadowPipelineState)

        for renderable in scene.renderables {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.render(renderEncoder: renderEncoder, uniforms: scene.uniforms, pipeline: shadowPipelineState)
            renderEncoder.popDebugGroup()
        }

        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }

    private func drawDebug(encoder: MTLRenderCommandEncoder) {
        debugLights(renderEncoder: encoder, lightType: Pointlight)
    }
}

private extension MTLRenderPassDescriptor {
    func setUpDepthAttachment(texture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        depthAttachment.clearDepth = 1
    } }

