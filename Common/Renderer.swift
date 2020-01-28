
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
    let model: Model!

    var scene: Scene?

    private var depthStencilState: MTLDepthStencilState!
//    private var instanceParamBuffer: MTLBuffer

    static var mtkView: MTKView!
    lazy var lightPipelineState: MTLRenderPipelineState = {
        return buildLightPipelineState()
    }()

    
    var shadowDepthTexture: MTLTexture!
    var shadowColorTexture: MTLTexture!
    let shadowRenderPassDescriptor = MTLRenderPassDescriptor()

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

        model = Model(name: "boy_tpose.usdz")
        model.scale = [0.015, 0.015, 0.015]
        model.position = [3, 0, 0]
        super.init()
        metalView.clearColor = MTLClearColor(red: 0, green: 0,
                                             blue: 0, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)

        buildDepthStencilState()


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
    }

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let scene = scene
        else {
            return
        } 

        let deltaTime = 1 / Float(view.preferredFramesPerSecond)

        scene.uniforms.projectionMatrix = scene.camera.projectionMatrix
        scene.uniforms.viewMatrix = scene.camera.viewMatrix

        model.update(deltaTime: deltaTime)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { fatalError() }
        renderEncoder.pushDebugGroup("Main pass")
        renderEncoder.label = "Main encoder"
        renderEncoder.setDepthStencilState(depthStencilState)

        var fragmentUniforms = FragmentUniforms()
        fragmentUniforms.cameraPosition = scene.camera.position
        fragmentUniforms.lightCount = UInt32(scene.lights.count)

//        renderEncoder.setFragmentBytes(&fragmentUniforms,
//                                       length: MemoryLayout<FragmentUniforms>.stride,
//                                       index: Int(BufferIndexFragmentUniforms.rawValue))

        
        renderEncoder.setFragmentBytes(&scene.lights,
                                       length: MemoryLayout<Light>.stride * scene.lights.count,
                                       index: Int(BufferIndexLights.rawValue))

        var farZ = Camera.FarZ
        renderEncoder.setFragmentBytes(&farZ, length: MemoryLayout<Float>.stride, index: 24)

//        model.render(renderEncoder: renderEncoder, uniforms: scene.uniforms)
        model.render(renderEncoder: renderEncoder, uniforms: scene.uniforms, fragmentUniforms: fragmentUniforms)

        renderEncoder.endEncoding()

        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
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
}

