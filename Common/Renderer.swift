
import MetalKit

final class Renderer: NSObject {

    static let sampleCount = 1

    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var colorPixelFormat: MTLPixelFormat!
    static var depthPixelFormat: MTLPixelFormat!
    static var drawableSize: CGSize!
    static var library: MTLLibrary?
    static let MaxVisibleFaces = 6
    static let MaxActors = 5
    static let MaxActorInstances = 50
    static let InstanceParamsBufferCapacity = Renderer.MaxActors * Renderer.MaxActorInstances * Renderer.MaxVisibleFaces

    var scene: Scene?

    private var depthStencilState: MTLDepthStencilState!
    private var instanceParamBuffer: MTLBuffer
    private var updateTerrain = true

    static var mtkView: MTKView!
    lazy var lightPipelineState: MTLRenderPipelineState = {
        return buildLightPipelineState()
    }()

    
    var shadowDepthTexture: MTLTexture!
    var shadowColorTexture: MTLTexture!
    let shadowRenderPassDescriptor = MTLRenderPassDescriptor()


    var albedoTexture: MTLTexture!
    var normalTexture: MTLTexture!
    var positionTexture: MTLTexture!
    var depthTexture: MTLTexture!

    var gBufferRenderPassDescriptor: MTLRenderPassDescriptor!

    var compositionPipelineState: MTLRenderPipelineState!
    var quadVerticesBuffer: MTLBuffer!
    var quadTexCoordsBuffer: MTLBuffer!
    let quadVertices: [Float] = [ -1.0, 1.0,
                                  1.0, -1.0, -1.0, -1.0, -1.0, 1.0,
                                  1.0, 1.0,
                                  1.0, -1.0 ]
    let quadTexCoords: [Float] = [ 0.0, 0.0,
                                   1.0, 1.0,
                                   0.0, 1.0,
                                   0.0, 0.0, 1.0, 0.0, 1.0, 1.0
    ]

    init(metalView: MTKView) {
        Renderer.mtkView = metalView
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }

        metalView.sampleCount = Renderer.sampleCount
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.device = device
        Renderer.device = device
        Renderer.commandQueue = device.makeCommandQueue()!
        Renderer.colorPixelFormat = metalView.colorPixelFormat
        Renderer.depthPixelFormat = metalView.depthStencilPixelFormat
        Renderer.library = device.makeDefaultLibrary()
        Renderer.drawableSize = metalView.drawableSize
        instanceParamBuffer = Renderer.device
            .makeBuffer(length: MemoryLayout<InstanceParams>.stride * Renderer.InstanceParamsBufferCapacity, options: .storageModeShared)!

        super.init()
        metalView.clearColor = MTLClearColor(red: 0, green: 0,
                                             blue: 0, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)

        buildDepthStencilState()
        buildShadowTexture(size: metalView.drawableSize)

        quadVerticesBuffer = Renderer.device.makeBuffer(bytes: quadVertices, length: MemoryLayout<Float>.size * quadVertices.count, options: [])
        quadVerticesBuffer.label = "Quad vertices"

        quadTexCoordsBuffer = Renderer.device.makeBuffer(bytes: quadTexCoords, length: MemoryLayout<Float>.size * quadTexCoords.count, options: [])
        quadTexCoordsBuffer.label = "Quad texCoords"

        buildCompositionPipelineState()
    }

    func buildGBufferRenderPassDescriptor(size: CGSize) {

        gBufferRenderPassDescriptor = MTLRenderPassDescriptor()
        buildGbufferTextures(size: size)
        let textures: [MTLTexture] = [albedoTexture,
                                      normalTexture,
                                      positionTexture]

        for (position, texture) in textures.enumerated() {
            gBufferRenderPassDescriptor.setUpColorAttachment( position: position, texture: texture)
        }

        gBufferRenderPassDescriptor.setUpDepthAttachment(texture: depthTexture)
    }

    func buildGbufferTextures(size: CGSize) {
        albedoTexture = buildTexture(pixelFormat: .bgra8Unorm,
                                     size: size, label: "Albedo texture")
        normalTexture = buildTexture(pixelFormat: .rgba16Float,
                                     size: size, label: "Normal texture")
        positionTexture = buildTexture(pixelFormat: .rgba16Float,
                                       size: size, label: "Position texture")
        depthTexture = buildTexture(pixelFormat: .depth32Float,
                                    size: size, label: "Depth texture")
    }

    func buildCubeTexture(pixelFormat: MTLPixelFormat, size: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor
            .textureCubeDescriptor(pixelFormat: pixelFormat,
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
        shadowDepthTexture = buildCubeTexture(pixelFormat: .depth32Float, size: Int(size.width))
        shadowColorTexture = buildCubeTexture(pixelFormat: .bgra8Unorm_srgb, size: Int(size.width))
        shadowRenderPassDescriptor.setUpCubeDepthAttachment(depthTexture: shadowDepthTexture, colorTexture: shadowColorTexture)
    }

    func buildDepthStencilState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depthStencilState = Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }

    func buildCompositionPipelineState() {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.label = "Composition state"

        descriptor.vertexFunction = Renderer.library!.makeFunction(name: "compositionVert")
        descriptor.fragmentFunction = Renderer.library!.makeFunction(name: "compositionFrag")

        do {
            compositionPipelineState = try Renderer.device.makeRenderPipelineState( descriptor: descriptor)
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

//        Tessellation Pass

        guard let terrain = scene.renderables.first(where: { $0 is Terrain }) as? Terrain else { fatalError() }

        if updateTerrain {
            guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { fatalError("Failed to make compute encoder") }
            computeEncoder.pushDebugGroup("Tessellation Pass")
            terrain.compute(computeEncoder: computeEncoder, uniforms: scene.uniforms)
            computeEncoder.popDebugGroup()
            computeEncoder.endEncoding()

            Terrain.generateTerrainNormalMap(heightMap: terrain.heightMap, normalTexture: terrain.normalMapTexture, commandBuffer: commandBuffer)

            updateTerrain = false
        }

        // Calculate Height

        guard let heightEncoder = commandBuffer.makeComputeCommandEncoder() else { fatalError() }
        heightEncoder.pushDebugGroup("Height pass")
        for renderable in scene.renderables {
            renderable.calculateHeight(computeEncoder: heightEncoder, heightMapTexture: terrain.heightMap, terrain: Terrain.terrainParams, uniforms: scene.uniforms, controlPointsBuffer: terrain.controlPointsBuffer)
        }
        heightEncoder.popDebugGroup()
        heightEncoder.endEncoding()


        // Shadow pass
        var previousUniforms = scene.uniforms
        guard let shadowEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptor) else {  return }
        renderShadowPass(renderEncoder: shadowEncoder, view: view)

        var fragmentUniforms = FragmentUniforms()
        fragmentUniforms.cameraPosition = scene.camera.position
        fragmentUniforms.lightCount = UInt32(scene.lights.count)
        fragmentUniforms.tiling = 1

        // main pass
        renderGbufferPass(commandBuffer: commandBuffer, uniforms: &previousUniforms, fragmentUniforms: &fragmentUniforms)

        // composition pass
        guard let compositionEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { fatalError() }
        renderCompositionPass(renderEncoder: compositionEncoder, fragmentUniforms: &fragmentUniforms)
        

        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

extension Renderer {
    func renderGbufferPass(commandBuffer: MTLCommandBuffer, uniforms: inout Uniforms, fragmentUniforms: inout FragmentUniforms) {

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: gBufferRenderPassDescriptor) else { fatalError() }
        guard let scene = scene else { fatalError() }

        renderEncoder.pushDebugGroup("Gbuffer pass")
        renderEncoder.label = "Gbuffer encoder"
        //        renderEncoder.setRenderPipelineState(gBufferPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setCullMode(.back)


        scene.uniforms.viewMatrix = uniforms.viewMatrix
        scene.uniforms.projectionMatrix = uniforms.projectionMatrix

        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: Int(BufferIndexFragmentUniforms.rawValue))


        // this needs to go somwehre else
        renderEncoder.setFragmentBytes(&scene.lights,
                                       length: MemoryLayout<Light>.stride * scene.lights.count,
                                       index: Int(BufferIndexLights.rawValue))

        renderEncoder.setFragmentTexture(shadowColorTexture, index: Int(ShadowColorTexture.rawValue))
        renderEncoder.setFragmentTexture(shadowDepthTexture, index: Int(ShadowDepthTexture.rawValue))


        var farZ = Camera.FarZ
        renderEncoder.setFragmentBytes(&farZ, length: MemoryLayout<Float>.stride, index: 24)

        for renderable in scene.renderables {
            // Allow set up for off screen targets
            renderable.renderToTarget(with: commandBuffer)
        }

        for renderable in scene.renderables {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.render(renderEncoder: renderEncoder, uniforms: scene.uniforms)
            renderEncoder.popDebugGroup()
        }

        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()

    }

    func renderCompositionPass(renderEncoder: MTLRenderCommandEncoder, fragmentUniforms: inout FragmentUniforms) {
        guard let scene = scene else { fatalError() }

        renderEncoder.pushDebugGroup("Composition pass")
        renderEncoder.label = "Composition encoder"

        renderEncoder.setRenderPipelineState(compositionPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)

        renderEncoder.setVertexBuffer(quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(albedoTexture, index: 0)
        renderEncoder.setFragmentTexture(normalTexture, index: 1)
        renderEncoder.setFragmentTexture(positionTexture, index: 2)

        renderEncoder.setFragmentBytes(&scene.lights, length: MemoryLayout<Light>.stride * scene.lights.count, index: 2)
        renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 3)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)

        scene.skybox?.render(renderEncoder: renderEncoder, uniforms: scene.uniforms)

        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
}

extension Renderer {
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
        renderEncoder.setFragmentBytes(&sunlight, length: MemoryLayout<Light>.stride, index: Int(BufferIndexLights.rawValue))

        for (actorIdx, renderable) in scene.renderables.enumerated() {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.renderShadow(renderEncoder: renderEncoder, uniforms: scene.uniforms, startingIndex: actorIdx * Renderer.MaxVisibleFaces)
            renderEncoder.popDebugGroup()
        }

        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }

    private func setLantern(view: MTKView, renderEncoder: MTLRenderCommandEncoder, sunlight: Light) {
        guard let scene = scene else { return }
        let aspect: Float = 1
        var near: Float = Camera.NearZ
        var far: Float = Camera.FarZ

        let projection = float4x4(projectionFov: radians(fromDegrees: 90), aspectRatio: aspect, nearZ: near, farZ: far)


        //        let projection = float4x4(perspectiveProjectionFov: radians(fromDegrees: 90), aspectRatio: aspect, nearZ: near, farZ: far)
        scene.uniforms.projectionMatrix = projection
        var viewMatrices = [CubeMap]()

        // Is this just because the sphere in demo spinning??
        let directions: [float3] = [
            [1, 0, 0],  // Right
            [-1, 0, 0], // Left
            [0, 1,  0], // Top
            [0, -1, 0], // Down
            [0, 0, 1],  // Front
            [0, 0, -1]  // Back
        ]

        let ups: [float3] = [
            [0, 1,  0], // Right
            [0, 1,  0], // Left
            [0, 0, -1], // Top
            [0, 0,  1], // Down
            [0, 1,  0], // Front
            [0, 1,  0]  // Back
        ]

        var culler_probe = [FrustumCuller]()

        // Build view matrix for each face of the cube map
        for i in 0..<6 {
            var map = CubeMap()
            map.direction = directions[i]
            map.up = ups[i]

            let position: float3 = [sunlight.position.x, sunlight.position.y, sunlight.position.z]
            let lookAt = float4x4(lookAtLHEye: position, target: position + directions[i], up: ups[i])
            map.faceViewMatrix = projection * lookAt
            viewMatrices.append(map)

            // Create frustums
            let cullerProbe = FrustumCuller(viewMatrix: map.faceViewMatrix,
                                            viewPosition: position,
                                            aspect: 1,
                                            halfAngleApertureHeight: .pi / 4,
                                            nearPlaneDistance: near,
                                            farPlaneDistance: far)

            culler_probe.append(cullerProbe)
        }


        for (actorIdx, renderable) in scene.renderables.enumerated() {
            guard let prop = renderable as? Prop else { continue }

            let bSphere = vector_float4((prop.boundingBox.maxBounds + prop.boundingBox.minBounds) * 0.5, simd_length(prop.boundingBox.maxBounds - prop.boundingBox.minBounds) * 0.5)

            for (transformIdx, transform) in prop.transforms.enumerated() {

                for (faceIdx, probe) in culler_probe.enumerated() {
                    //                    if probe.Intersects(actorPosition: transform.position, bSphere: bSphere) {

                    //                        prop.updateShadowBuffer(transformIndex: (transformIdx * 6) + faceIdx, viewPortIndex: faceIdx)
                    //                    }
                }
            }
        }

        // setVertexBytes instanceParams

        renderEncoder.setVertexBytes(&viewMatrices,
                                     length: MemoryLayout<CubeMap>.stride * viewMatrices.count,
                                     index: Int(BufferIndexCubeFaces.rawValue))

        renderEncoder.setVertexBuffer(instanceParamBuffer,
                                      offset: 0,
                                      index: Int(BufferIndexInstanceParams.rawValue))

        renderEncoder.setFragmentBytes(&far, length: MemoryLayout<Float>.stride, index: 10)
        renderEncoder.setFragmentBytes(&near, length: MemoryLayout<Float>.stride, index: 11)
    }


    private func setSpotlight(view: MTKView, sunlight: Light) {
        guard let scene = scene else { return }
        let aspect = Float(view.bounds.width) / Float(view.bounds.height)
        scene.uniforms.projectionMatrix = float4x4(projectionFov: radians(fromDegrees: 70), aspectRatio: aspect, nearZ: 0.01, farZ: 16)
        //        scene.uniforms.projectionMatrix = float4x4(perspectiveProjectionFov: radians(fromDegrees: 70), aspectRatio: aspect, nearZ: 0.01, farZ: 16)


        let position: float3 = [-sunlight.position.x, -sunlight.position.y, -sunlight.position.z]
        let lookAt = float4x4(lookAtLHEye: position, target: position - sunlight.coneDirection, up: [0, 1, 0])

        // they work if this is 7
        scene.uniforms.viewMatrix = float4x4(translation: [0, 0, 7]) * lookAt
        scene.uniforms.shadowMatrix = scene.uniforms.projectionMatrix * scene.uniforms.viewMatrix
    }

    private func drawDebug(encoder: MTLRenderCommandEncoder) {
        encoder.pushDebugGroup("DEBUG LIGHTS")
        guard let gameScene = scene as? GameScene else { return }
        debugLights(renderEncoder: encoder, lightType: Pointlight, direction: gameScene.camera.position)
        encoder.popDebugGroup()
    }
}

private extension MTLRenderPassDescriptor {
    func setUpDepthAttachment(texture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        depthAttachment.clearDepth = 1
    }


    func setUpCubeDepthAttachment(depthTexture: MTLTexture, colorTexture: MTLTexture) {
        colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1.0)
        colorAttachments[0].loadAction = .clear
        colorAttachments[0].texture = colorTexture

        depthAttachment.texture = depthTexture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        depthAttachment.clearDepth = 1

        renderTargetArrayLength = 6

    }

    func setUpColorAttachment(position: Int, texture: MTLTexture) {
        let attachment: MTLRenderPassColorAttachmentDescriptor = colorAttachments[position]
        attachment.texture = texture
        attachment.loadAction = .clear
        attachment.storeAction = .store
        attachment.clearColor = MTLClearColorMake(0.73, 0.92, 1, 1)
    }
}

