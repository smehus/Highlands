
import MetalKit

struct Mesh {
    let mtkMesh: MTKMesh
    let submeshes: [Submesh]
    let transform: TransformComponent?
    let skeleton: Skeleton?

    init(mdlMesh: MDLMesh, mtkMesh: MTKMesh,
         startTime: TimeInterval,
         endTime: TimeInterval)
    {
        let skeleton =
            Skeleton(animationBindComponent:
                (mdlMesh.componentConforming(to: MDLComponent.self)
                    as? MDLAnimationBindComponent))
        self.skeleton = skeleton

        self.mtkMesh = mtkMesh
        submeshes = zip(mdlMesh.submeshes!, mtkMesh.submeshes).map { mesh in
            Submesh(submesh: mesh.1, mdlSubmesh: mesh.0 as! MDLSubmesh, type: .character)
        }
        if let mdlMeshTransform = mdlMesh.transform {
            transform = TransformComponent(transform: mdlMeshTransform,
                                           object: mdlMesh,
                                           startTime: startTime,
                                           endTime: endTime)
        } else {
            transform = nil
        }

    }
}
