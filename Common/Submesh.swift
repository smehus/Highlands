//
//  Submesh.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

class Submesh {

    struct Textures {
        let baseColor: MTLTexture?
    }

    let textures: Textures
    var submesh: MTKSubmesh

    init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh) {
        self.submesh = submesh
        textures = Textures(material: mdlSubmesh.material)
    }
}

extension Submesh: Texturable { }

private extension Submesh.Textures {
    init(material: MDLMaterial?) {
        guard
            let property = material?.property(with: .baseColor),
            property.type == .string,
            let filename = property.stringValue,
            let texture = try? Submesh.loadTexture(imageName: filename)
        else {
            baseColor = nil
            return
        }

        baseColor = texture
    }
}
