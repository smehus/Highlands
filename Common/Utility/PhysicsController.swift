

import MetalKit

// Render bounding boxes
let debugRenderBoundingBox = false
class PhysicsController {

    var dynamicBody: Node?
    var staticBodies: [Node] = []

    var holdAllCollided = true
    var collidedBodies: [Node] = []

    func addStaticBody(node: Node) {
        removeBody(node: node)
        staticBodies.append(node)
    }

    func removeBody(node: Node) {
        if let index = staticBodies.firstIndex(where: {
            $0.self === node
        }) {
            staticBodies.remove(at: index)
        }
    }

    func checkCollisions() -> Bool {
        collidedBodies = []
        guard let node = dynamicBody else { return false }
        let nodeRadius = max((node.size.x / 2), (node.size.z / 2))
        // This calculates the flaot3 position of the node
        let nodePosition = node.worldTransform.columns.3.xyz
        
        for body in staticBodies  {
            let bodyRadius = max((body.size.x / 2), (body.size.z / 2))
            if let prop = body as? Prop, prop.propType.isInstanced {
                for transform in prop.transforms {
                    let bodyPosition = transform.modelMatrix.columns.3.xyz
                    let d = distance(nodePosition, bodyPosition)
                    if d < (nodeRadius + bodyRadius) {
                        if holdAllCollided {
                            collidedBodies.append(body)
                        } else {
                            return true
                        }
                    }
                }
            } else {
                let bodyPosition = body.worldTransform.columns.3.xyz
                let d = distance(nodePosition, bodyPosition)
                if d < (nodeRadius + bodyRadius) {
                    if holdAllCollided {
                        collidedBodies.append(body)
                    } else {
                        return true
                    }
                }
            }
        }

        return collidedBodies.count != 0
    }
}
