
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
    static var mtkView: MTKView!

    var scene: Scene?




    init(metalView: MTKView) {
        Renderer.mtkView = metalView
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }

        metalView.sampleCount = Renderer.sampleCount
        metalView.depthStencilPixelFormat = .depth32Float_stencil8
        metalView.device = device
//        metalView.preferredFramesPerSecond = 30
        Renderer.device = device
        Renderer.commandQueue = device.makeCommandQueue()!
        Renderer.colorPixelFormat = metalView.colorPixelFormat
        Renderer.depthPixelFormat = metalView.depthStencilPixelFormat
        Renderer.library = device.makeDefaultLibrary()
        Renderer.drawableSize = metalView.drawableSize

        super.init()
        metalView.clearColor = MTLClearColor(red: 0, green: 0,
                                             blue: 0, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
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
        scene.update(deltaTime: deltaTime)
        scene.render(view: view, descriptor: descriptor, commandBuffer: commandBuffer)

        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
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
}

extension MTLRenderPassDescriptor {
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

