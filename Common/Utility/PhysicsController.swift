

import MetalKit

// Render bounding boxes
let debugRenderBoundingBox = false
class PhysicsController {

    var dynamicBody: Node?
    var staticBodies: [Node] = []

    var holdAllCollided = true
    var collidedBodies: [Positionable] = []

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

    func checkCollisions() -> [Positionable] {
        collidedBodies = []
        guard let node = dynamicBody else { return [] }
        let nodeRadius = max((node.size.x / 2), (node.size.z / 2))
        // This calculates the flaot3 position of the node
        let nodePosition = node.worldTransform.columns.3.xyz

        //


        func t(iteratedTransform: Transform, n1Position: SIMD3<Float>, n1Radius: Float, n2Radius: Float) -> Bool {
            let bodyPosition = iteratedTransform.modelMatrix.columns.3.xyz
            let d = distance(n1Position, bodyPosition)
            if d < (n1Radius + n2Radius) {
                if holdAllCollided {
                    return true
                } else {
                    return false
                }
            }

            return false
        }

        /// Handling collisions with player
        for body in staticBodies  {
            let bodyRadius = max((body.size.x / 2), (body.size.z / 2))
            if let prop = body as? Prop, prop.propType.isInstanced {
                for transform in prop.transforms {
                    if t(iteratedTransform: transform,
                         n1Position: nodePosition,
                         n1Radius: nodeRadius,
                         n2Radius: bodyRadius) {

                        collidedBodies.append(transform)
                    }
                }
            } else {
                let bodyPosition = body.worldTransform.columns.3.xyz
                let d = distance(nodePosition, bodyPosition)
                if d < (nodeRadius + bodyRadius) {
                    if holdAllCollided {
                        collidedBodies.append(body)
                    } else {
                        return []
                    }
                }
            }
        }

        return collidedBodies
    }
}
