

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


        func t(p1: SIMD3<Float>, p2: SIMD3<Float>, r1: Float, r2: Float) -> Bool {
            if distance(p1, p2) < (r1 + r2) {
                if holdAllCollided {
                    return true
                } else {
                    return false
                }
            }

            return false
        }


        for case let (index, body) in staticBodies.enumerated() {
            guard let prop = body as? Prop, prop.propType.isInstanced else { continue }
            let bodyRadius = max((prop.size.x / 2), (prop.size.z / 2))
            for (transformIndex, transform) in prop.transforms.enumerated() {
                // Test player collision
                if t(p1: nodePosition, p2: transform.modelMatrix.columns.3.xyz, r1: nodeRadius, r2: bodyRadius) {
                    collidedBodies.append(transform)
                }

                // Test prop to prop collision
                for (comparandIndex, comparandBody) in staticBodies.enumerated() {
                    let comparandRadius = max((prop.size.x / 2), (prop.size.z / 2))
                    guard let prop = body as? Prop, prop.propType.isInstanced else { continue }
                    for (comparanandTransformIndex, comparandTransform) in prop.transforms.enumerated() {
                        guard !(comparandIndex == index && comparanandTransformIndex == transformIndex) else { continue }
                        guard !collidedBodies.contains(where: { (positionable) -> Bool in
                            guard let t = positionable as? Transform, !(t == comparandTransform) else { return false }
                            return true
                        }) else { continue }

                        // Does comparand transfrom collide with base transform iteration.
                        if t(p1: comparandTransform.position, p2: transform.position, r1: comparandRadius, r2: bodyRadius) {
                            collidedBodies.append(comparandTransform)
                        }
                    }
                }
            }
        }

        print("*** COLLIDED BODIES \(collidedBodies.count)")
        return collidedBodies
    }
}
