//
//  Texturable.swift
//  Highlands-iOS
//
//  Created by Scott Mehus on 12/8/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

protocol Texturable { }

extension Texturable {
    static func loadTexture(imageName: String) throws -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: Renderer.device)
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] =
            // TODO: WHAT THE FUCK? gltf textures are loading upside down you dumbass
            [/*.origin: MTKTextureLoader.Origin.bottomLeft,*/
             .SRGB: false,
             .generateMipmaps: NSNumber(booleanLiteral: true)]

        let fileExtension = URL(fileURLWithPath: imageName).pathExtension.isEmpty ? "png" : nil

        guard let url = Bundle.main.url(forResource: imageName, withExtension: fileExtension) else {
            return try textureLoader.newTexture(name: imageName, scaleFactor: 1.0, bundle: Bundle.main, options: nil)
        }

        print("Loaded texture: \(imageName)")
        let texture = try textureLoader.newTexture(URL: url, options: textureLoaderOptions)
        return texture
    }

    static func loadCubeTexture(imageName: String) throws -> MTLTexture {
        // MDLTexure can't load from asset catalog
        let textureLoader = MTKTextureLoader(device: Renderer.device)

        if let texture = MDLTexture(cubeWithImagesNamed: [imageName]) {
            let options: [MTKTextureLoader.Option: Any] =
                [.origin: MTKTextureLoader.Origin.topLeft,
                 .SRGB: false,
                 .generateMipmaps: NSNumber(booleanLiteral: false)]
            return try textureLoader.newTexture(texture: texture, options: options)
        }

        let texture = try textureLoader.newTexture(name: imageName, scaleFactor: 1.0,
                                                   bundle: .main)
        return texture
    }
}
