
import MetalKit

class RenderPass {
  var descriptor: MTLRenderPassDescriptor
  var texture: MTLTexture
  var depthTexture: MTLTexture
  let name: String
  
  init(name: String, size: CGSize) {
    self.name = name
    texture = RenderPass.buildTexture(size: size, label: name,
                                      pixelFormat: .bgra8Unorm)
    depthTexture = RenderPass.buildTexture(size: size, label: name,
                                           pixelFormat: .depth32Float)
    descriptor = RenderPass.setupRenderPassDescriptor(texture: texture,
                                                      depthTexture: depthTexture)
  }
  
  func updateTextures(size: CGSize) {
    texture = RenderPass.buildTexture(size: size, label: name,
                                      pixelFormat: .bgra8Unorm)
    depthTexture = RenderPass.buildTexture(size: size, label: name,
                                           pixelFormat: .depth32Float)
    descriptor = RenderPass.setupRenderPassDescriptor(texture: texture,
                                                      depthTexture: depthTexture)
  }
  
  static func setupRenderPassDescriptor(texture: MTLTexture,
                                        depthTexture: MTLTexture) -> MTLRenderPassDescriptor {
    let descriptor = MTLRenderPassDescriptor()
    descriptor.setUpColorAttachment(position: 0, texture: texture)
    descriptor.setUpDepthAttachment(texture: depthTexture)
    return descriptor
  }
  
  static func buildTexture(size: CGSize,
                           label: String,
                           pixelFormat: MTLPixelFormat) -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                              width: Int(size.width * 0.5),
                                                              height: Int(size.height * 0.5),
                                                              mipmapped: false)
    descriptor.sampleCount = 1
    descriptor.storageMode = .private
    descriptor.textureType = .type2D
    descriptor.usage = [.renderTarget, .shaderRead]
    guard let texture = TemplateRenderer.device.makeTexture(descriptor: descriptor) else {
      fatalError("Texture not created")
    }
    texture.label = label
    return texture
  }
 }

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
