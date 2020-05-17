

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

        // Find first body / transform with collison with player
        // Should refactor to use flatMap / firstWhere etc
        for body in staticBodies {
            let bodyRadius = max(body.size.x / 2, body.size.z / 2)
            let transforms = body.transforms

            guard let playerCollidedTransform = transforms.first(where: { (transform) -> Bool in
                  return distance(player.position, transform.position) < (playerRadius + bodyRadius)
              }) else { continue }


            playerCollidedTransform.position += playerMovement
             playerCollidedTransform.isColliding = true

             // Return a bool from this function
             // 'containsFutureCollisionWithSolidObject'
             // But we need to refector to inject the prop type? Or something
             let containsFutureCollisionWithSolidObject = findAllCollisions(
                 playerRadius: playerRadius,
                 propRadius: bodyRadius,
                 transform: playerCollidedTransform,
                 allTransforms: transforms,
                 move: playerMovement
             )

             if !containsFutureCollisionWithSolidObject {
                 // Add prop movement
             }

            return
        }
    }

    private func findAllCollisions(playerRadius: Float, propRadius: Float, transform: Transform, allTransforms: [Transform], move: SIMD3<Float>) -> Bool {

        let nonCollidedTransforms = allTransforms.filter { !$0.isColliding }

        for checkTransform in nonCollidedTransforms {
            if distance(transform.position, checkTransform.position) < (propRadius + propRadius) {
                checkTransform.position += move
                checkTransform.isColliding = true
                return findAllCollisions(
                    playerRadius: playerRadius,
                    propRadius: propRadius,
                    transform: checkTransform,
                    allTransforms: nonCollidedTransforms,
                    move: move
                )
            }
        }

        return false
    }
}
