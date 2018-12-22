

import MetalKit

// Render bounding boxes
let debugRenderBoundingBox = false
class PhysicsController {
  
  var dynamicBody: Node?
  var staticBodies: [Node] = []
  
  func addStaticBody(node: Node) {
    removeBody(node: node)
    staticBodies.append(node)
  }
  
  func removeBody(node: Node) {
    if let index = staticBodies.index(where: {
      $0.self === node
    }) {
      staticBodies.remove(at: index)
    }
  }
}
