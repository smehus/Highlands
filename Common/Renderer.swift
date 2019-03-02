
import MetalKit

final class Renderer: NSObject {

    static let sampleCount = 1

    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var colorPixelFormat: MTLPixelFormat!
    static var library: MTLLibrary?

    var scene: Scene?

    private var depthStencilState: MTLDepthStencilState!

    lazy var lightPipelineState: MTLRenderPipelineState = {
        return buildLightPipelineState()
    }()

    
    var shadowTexture: MTLTexture!
    let shadowRenderPassDescriptor = MTLRenderPassDescriptor()

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

    }

    func buildCubeTexture(size: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor
            .textureCubeDescriptor(pixelFormat: .depth32Float,
                                   size: size,
                                   mipmapped: false)

        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private

        guard let texture = Renderer.device.makeTexture(descriptor: descriptor) else {
            fatalError()
        }

        texture.label = "CUBE POINTLIGHT TEXTURE"
        return texture
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
//        shadowTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Shadow")
//        shadowRenderPassDescriptor.setUpDepthAttachment(texture: shadowTexture)

        // Pointlights
        shadowTexture = buildCubeTexture(size: Int(size.width))
        shadowRenderPassDescriptor.setUpCubeDepthAttachment(texture: shadowTexture)

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

        renderShadowPass(renderEncoder: shadowEncoder, view: view)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return 
        }

        renderEncoder.pushDebugGroup("Main pass")
        renderEncoder.label = "Main encoder"
        renderEncoder.setDepthStencilState(depthStencilState)

        var fragmentUniforms = FragmentUniforms()
        fragmentUniforms.cameraPosition = scene.camera.position
        fragmentUniforms.lightCount = UInt32(scene.lights.count)

        // Reset uniforms so projection is correct
        // GOOOOOOD LOORD i'm totally resetting the shadow matrix here
        // goodddddddd damniiitttttt
//        scene.uniforms = previousUniforms
//        scene.uniforms.modelMatrix = previousUniforms.modelMatrix
//        scene.uniforms.normalMatrix = previousUniforms.normalMatrix
        scene.uniforms.viewMatrix = previousUniforms.viewMatrix
        scene.uniforms.projectionMatrix = previousUniforms.projectionMatrix

        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: Int(BufferIndexFragmentUniforms.rawValue))

        
        renderEncoder.setFragmentBytes(&scene.lights,
                                       length: MemoryLayout<Light>.stride * scene.lights.count,
                                       index: Int(BufferIndexLights.rawValue))

        renderEncoder.setFragmentTexture(shadowTexture, index: Int(ShadowTexture.rawValue))

        for renderable in scene.renderables {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.render(renderEncoder: renderEncoder, uniforms: scene.uniforms)
            renderEncoder.popDebugGroup()
        }

        scene.skybox?.render(renderEncoder: renderEncoder, uniforms: scene.uniforms)

        drawDebug(encoder: renderEncoder)

        renderEncoder.endEncoding()

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

        var sunlight = scene.lights.first!

//        let rect = Rectangle(left: -8, right: 8, top: 8, bottom: -8)
//        scene.uniforms.projectionMatrix = float4x4(orthographic: rect, near: 0.1, far: 16)

//        setSpotlight(view: view, sunlight: sunlight)
        setLantern(view: view, renderEncoder: renderEncoder, sunlight: sunlight)

        renderEncoder.setVertexBytes(&sunlight, length: MemoryLayout<Light>.stride, index: Int(BufferIndexLights.rawValue))

        for renderable in scene.renderables {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.renderShadow(renderEncoder: renderEncoder, uniforms: scene.uniforms)
            renderEncoder.popDebugGroup()
        }

        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }

    private func setLantern(view: MTKView, renderEncoder: MTLRenderCommandEncoder, sunlight: Light) {
        guard let scene = scene else { return }
        let aspect = Float(view.bounds.width) / Float(view.bounds.height)
        scene.uniforms.projectionMatrix = float4x4(projectionFov: radians(fromDegrees: 90), near: 0.01, far: 16, aspect: aspect)

        var viewMatrices = [CubeMap]()

        // Is this just because the sphere in demo spinning??
        let directions: [float3] = [
            [ 1,  0,  0], // Right
            [-1,  0,  0], // Left
            [ 0,  1,  0], // Top
            [ 0, -1,  0], // Down
            [ 0,  0,  1], // Front
            [ 0,  0, -1]  // Back
        ]

        let ups: [float3] = [
            [0, 1,  0],
            [0, 1,  0],
            [0, 0, -1],
            [0, 0,  1],
            [0, 1,  0],
            [0, 1,  0]
        ]


        // Build view matrix for each face of the cube map
        for i in 0..<6 {
            var map = CubeMap()
            map.direction = directions[i]
            map.up = ups[i]

            let position: float3 = [sunlight.position.x, sunlight.position.y, sunlight.position.z]
            let lookAt = float4x4(eye: position, center: position  + directions[i] , up: ups[i])
            map.faceViewMatrix = float4x4(translation: position) * lookAt
            

            viewMatrices.append(map)
        }

        renderEncoder.setVertexBytes(&viewMatrices,
                                     length: MemoryLayout<CubeMap>.stride * viewMatrices.count,
                                     index: Int(BufferIndexCubeFaces.rawValue))

    }

    private func setSpotlight(view: MTKView, sunlight: Light) {
        guard let scene = scene else { return }
        let aspect = Float(view.bounds.width) / Float(view.bounds.height)
        scene.uniforms.projectionMatrix = float4x4(projectionFov: radians(fromDegrees: 70), near: 0.01, far: 16, aspect: aspect)


        let position: float3 = [-sunlight.position.x, -sunlight.position.y, -sunlight.position.z]
        let lookAt = float4x4(eye: position, center: position - sunlight.coneDirection, up: [0,1,0])

        // they work if this is 7
        scene.uniforms.viewMatrix = float4x4(translation: [0, 0, 7]) * lookAt
        scene.uniforms.shadowMatrix = scene.uniforms.projectionMatrix * scene.uniforms.viewMatrix
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
    }


    func setUpCubeDepthAttachment(texture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        renderTargetArrayLength = 6
        depthAttachment.clearDepth = 1
    }
}

