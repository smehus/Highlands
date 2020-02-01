//
//  Mesh.swift
//  Highlands
//
//  Created by Scott Mehus on 12/31/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

import MetalKit

struct Mesh {
    let mtkMesh: MTKMesh
    let submeshes: [Submesh]
    let transform: TransformComponent?
    let skeleton: Skeleton?

    init(mdlMesh: MDLMesh, mtkMesh: MTKMesh, startTime: TimeInterval, endTime: TimeInterval, modelType: ModelType) {
        self.mtkMesh = mtkMesh

        skeleton = Skeleton(animationBindComponent: mdlMesh.componentConforming(to: MDLComponent.self) as? MDLAnimationBindComponent)

        submeshes = zip(mdlMesh.submeshes!, mtkMesh.submeshes).map { mesh in
            return Submesh(submesh: mesh.1, mdlSubmesh: mesh.0 as! MDLSubmesh, type: modelType)
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
