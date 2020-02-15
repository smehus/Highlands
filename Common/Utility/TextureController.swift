//
//  TextureController.swift
//  Highlands
//
//  Created by Scott Mehus on 2/15/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import MetalKit

struct TextureWrapper {
    let name: String
    let texture: MTLTexture
}

class TextureController {
    static var textures: [TextureWrapper] = []

    static func addTexture(texture: TextureWrapper?) -> Int? {
        guard let texture = texture else { return nil }

        TextureController.textures.append(texture)
        return TextureController.textures.count - 1
    }
}
