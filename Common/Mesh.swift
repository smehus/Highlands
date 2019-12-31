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

    init(mdlMesh: MDLMesh, mtkMesh: MTKMesh, propType: PropType) {
    self.mtkMesh = mtkMesh
    submeshes = zip(mdlMesh.submeshes!, mtkMesh.submeshes).map { mesh in
        return Submesh(submesh: mesh.1, mdlSubmesh: mesh.0 as! MDLSubmesh, type: propType)
    }
  }
}
