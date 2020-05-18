

import MetalKit

// Render bounding boxes
let debugRenderBoundingBox = true
class PhysicsController {

    var dynamicBody: Node?
    var staticBodies: [Prop] = []

    var holdAllCollided = true
    var collidedBodies: [Positionable] = []

    func addStaticBody(node: Prop) {
        removeBody(node: node)
        staticBodies.append(node)
    }

    func removeBody(node: Prop) {
        if let index = staticBodies.firstIndex(where: {
            $0.self === node
        }) {
            staticBodies.remove(at: index)
        }
    }

    func checkPlayerCollisions(playerMovement: SIMD3<Float>) {
        guard let player = dynamicBody as? Character else { assertionFailure(); return }
        let playerRadius = max(player.size.x / 2, player.size.z / 2)

        staticBodies.flatMap { $0.transforms }.forEach { $0.isColliding = false }

        // Find first transform / body

        var collidedTransform: Transform?
        var collidedProp: Prop?

        Outer: for body in staticBodies {

            let bodyRadius = max(body.size.x / 2, body.size.z / 2)
            let transforms = body.transforms

            guard let playerCollidedTransform = transforms.first(where: { (transform) -> Bool in
                  return distance(player.position, transform.position) < (playerRadius + bodyRadius)
              }) else { continue }


            collidedProp = body
            collidedTransform = playerCollidedTransform

            break Outer
        }

        guard let playerCollidedTransform = collidedTransform, let playerCollidedProp = collidedProp else { return }

        playerCollidedTransform.isColliding = true

        let containsFutureCollisionWithSolidObject = findAllCollisions(
            prop: playerCollidedProp,
            transform: playerCollidedTransform,
            move: playerMovement
        )

         if !containsFutureCollisionWithSolidObject {
             playerCollidedTransform.position += playerMovement
         }
    }


    private func findAllCollisions(prop: Prop, transform: Transform, move: SIMD3<Float>) -> Bool {
        let bodyRadius = max(prop.size.x / 2, prop.size.z / 2)

        for iteratedProp in staticBodies {

            let nonCollidingTransforms = iteratedProp.transforms.filter { !$0.isColliding }
            let iterationPropRadius = max(iteratedProp.size.x / 2, iteratedProp.size.z / 2)

            for iteratedTransform in nonCollidingTransforms {
                if distance(transform.position + move, iteratedTransform.position) < (bodyRadius + iterationPropRadius) {
                    iteratedTransform.isColliding = true

                    let containsFutureHold = findAllCollisions(prop: iteratedProp, transform: iteratedTransform, move: move)

                    if !containsFutureHold {
                        iteratedTransform.position += move
                    }

                    return containsFutureHold
                }
            }
        }


//        let nonCollidedTransforms = allTransforms.filter { !$0.isColliding }

//        for checkTransform in nonCollidedTransforms {
//            if distance(transform.position, checkTransform.position) < (propRadius + propRadius) {
//                checkTransform.position += move
//                checkTransform.isColliding = true
//                return findAllCollisions(
//                    playerRadius: playerRadius,
//                    propRadius: propRadius,
//                    transform: checkTransform,
//                    allTransforms: nonCollidedTransforms,
//                    move: move
//                )
//            }
//        }

        return false
    }
}
