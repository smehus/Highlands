//
//  TextureController.swift
//  Highlands
//
//  Created by Scott Mehus on 2/15/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import MetalKit


class TextureController {
    static var textures: [MTLTexture] = []

    static func addTexture(texture: MTLTexture?) -> Int? {
        guard let texture = texture else { return nil }
        TextureController.textures.append(texture)
        return TextureController.textures.count - 1
    }
}
