

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

    func checkPlayerCollisions(playerMovement: SIMD3<Float>) {
        guard let player = dynamicBody as? Character else { assertionFailure(); return }
        let playerRadius = max(player.size.x / 2, player.size.z / 2)

        for case let prop as Prop in staticBodies {
            let propRadius = max(prop.size.x / 2, prop.size.z / 2)

            for transform in prop.transforms {
                transform.isColliding = false
                if distance(player.position, transform.position) < (playerRadius + propRadius) {
                    transform.position += playerMovement
                    transform.isColliding = true
                }
            }
        }
    }

    func checkPropCollisions(playerMovement: SIMD3<Float>) {
        let prop = staticBodies.compactMap { $0 as? Prop }.first!
        var transforms = prop.transforms

        while !transforms.isEmpty {
            let checkTransform = transforms.removeFirst()

            for (index, transform) in transforms.enumerated() {
                if distance(checkTransform.position, transform.position) < max(prop.size.x, prop.size.z) {
                    if !transform.isColliding {
                        transforms.remove(at: index).position += playerMovement
                    } else {
                        checkTransform.position += playerMovement
                    }
                }
            }
        }
    }
}
