//
/**
 * Copyright (c) 2019 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import MetalKit

class TemplateRenderer: NSObject {
  static var device: MTLDevice!
  static var commandQueue: MTLCommandQueue!
  static var library: MTLLibrary!
  static var colorPixelFormat: MTLPixelFormat!
  static var fps: Int!
    static var mtkView: MTKView!

  var uniforms = Uniforms()
  var fragmentUniforms = FragmentUniforms()
  let depthStencilState: MTLDepthStencilState
  let lighting = TemplateLighting()
    static var drawableSize: CGSize!

  lazy var camera: TemplateCamera = {
    let camera = ArcballCamera()
    camera.distance = 8
    camera.target = [0, 1.3, 0]
//    camera.rotation.x = Float(-15).degreesToRadians
    return camera
  }()

  // Array of Models allows for rendering multiple models
  var models: [TemplateRenderable] = []

  var currentTime: Float = 0
  var ballVelocity: Float = 0
  
  init(metalView: MTKView) {
    guard
      let device = MTLCreateSystemDefaultDevice(),
      let commandQueue = device.makeCommandQueue() else {
        fatalError("GPU not available")
    }
    TemplateRenderer.device = device
    TemplateRenderer.commandQueue = commandQueue
    TemplateRenderer.library = device.makeDefaultLibrary()
    TemplateRenderer.colorPixelFormat = metalView.colorPixelFormat
    TemplateRenderer.fps = metalView.preferredFramesPerSecond
    TemplateRenderer.drawableSize = metalView.drawableSize
    TemplateRenderer.mtkView = metalView
    
    metalView.device = device
    metalView.depthStencilPixelFormat = .depth32Float
    
    depthStencilState = TemplateRenderer.buildDepthStencilState()!
    super.init()
    metalView.clearColor = MTLClearColor(red: 0.49, green: 0.62,
                                         blue: 0.75, alpha: 1)
    metalView.delegate = self
    mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)

    // models
    let skeleton = Character(name: "boy_tpose.usdz")
    skeleton.rotation = [.pi / 2, 0, radians(fromDegrees: 180)]
    skeleton.scale = [0.02, 0.02, 0.02]
    models.append(skeleton)
//    let ground = Model(name: "ground.obj")
//    ground.scale = [100, 100, 100]
//    models.append(ground)
    
    fragmentUniforms.lightCount = lighting.count
  }
  

  static func buildDepthStencilState() -> MTLDepthStencilState? {
    let descriptor = MTLDepthStencilDescriptor()
    descriptor.depthCompareFunction = .less
    descriptor.isDepthWriteEnabled = true
    return
      TemplateRenderer.device.makeDepthStencilState(descriptor: descriptor)
  }
}

extension TemplateRenderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    camera.aspect = Float(view.bounds.width)/Float(view.bounds.height)
  }
  
  func draw(in view: MTKView) {
    guard
      let descriptor = view.currentRenderPassDescriptor,
      let commandBuffer = TemplateRenderer.commandQueue.makeCommandBuffer(),
      let renderEncoder =
      commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
        return
    }
    
    let deltaTime = 1 / Float(TemplateRenderer.fps)
    for model in models {
      (model as? Character)?.update(deltaTime: deltaTime)
    }
    
    renderEncoder.setDepthStencilState(depthStencilState)

    uniforms.projectionMatrix = camera.projectionMatrix
    uniforms.viewMatrix = camera.viewMatrix
    fragmentUniforms.cameraPosition = camera.position
    
    var lights = lighting.lights
    renderEncoder.setFragmentBytes(&lights,
                                   length: MemoryLayout<Light>.stride * lights.count,
                                   index: Int(BufferIndexLights.rawValue))

    // render all the models in the array
    for model in models {
      renderEncoder.pushDebugGroup(model.name)
      model.render(renderEncoder: renderEncoder,
                    uniforms: uniforms,
                   fragmentUniforms: fragmentUniforms)
      renderEncoder.popDebugGroup()
    }

    renderEncoder.endEncoding()
    guard let drawable = view.currentDrawable else {
      return
    }
    commandBuffer.present(drawable)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
  }
}
