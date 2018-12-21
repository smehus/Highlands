
import MetalKit

final class Renderer: NSObject {

    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var colorPixelFormat: MTLPixelFormat!
    static var library: MTLLibrary?
    private var depthStencilState: MTLDepthStencilState!

    lazy var lights: [Light] = {
        return lighting()
    }()

    var scene: Scene?

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
        metalView.clearColor = MTLClearColor(red: 0.7, green: 0.9,
                                             blue: 1, alpha: 1)
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
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
            let scene = scene
        else {
                return
        }

        let deltaTime = 1 / Float(view.preferredFramesPerSecond)
        scene.update(deltaTime: deltaTime)

        renderEncoder.setDepthStencilState(depthStencilState)

        var fragmentUniforms = FragmentUniforms()
        fragmentUniforms.cameraPosition = scene.camera.position
        fragmentUniforms.lightCount = UInt32(lights.count)

        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: Int(BufferIndexFragmentUniforms.rawValue))

        renderEncoder.setFragmentBytes(&lights,
                                       length: MemoryLayout<Light>.stride * lights.count,
                                       index: Int(BufferIndexLights.rawValue))

        for renderable in scene.renderables {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.render(renderEncoder: renderEncoder, uniforms: scene.uniforms)
            renderEncoder.popDebugGroup()
        }

        renderEncoder.endEncoding()

        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}


