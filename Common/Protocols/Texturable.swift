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
    static func loadTextureArray(textureNames: [String]) -> TextureWrapper? {
        var textures: [MTLTexture] = []
        var hashedName = ""
        for textureName in textureNames {
            do {
                if let texture = try Submesh.loadTexture(imageName: textureName) {
                    textures.append(texture)
                    hashedName += textureName
                }
            } catch {
                fatalError(error.localizedDescription)
            }
        }

        guard textures.count > 0 else { return nil }

        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2DArray
        descriptor.pixelFormat = textures[0].pixelFormat
        descriptor.width = textures[0].width
        descriptor.height = textures[0].height
        descriptor.arrayLength = textures.count
        let arrayTexture = Renderer.device.makeTexture(descriptor: descriptor)!

        let commandBuffer = Renderer.commandQueue.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        let origin = MTLOrigin(x: 0, y: 0, z: 0)
        let size = MTLSize(width: arrayTexture.width,
                           height: arrayTexture.height, depth: 1)
        for (index, texture) in textures.enumerated() {
            blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0,
                             sourceOrigin: origin, sourceSize: size,
                             to: arrayTexture, destinationSlice: index,
                             destinationLevel: 0, destinationOrigin: origin)
        }
        blitEncoder.endEncoding()
        commandBuffer.commit()
        return TextureWrapper(name: hashedName, texture: arrayTexture)
    }

    static func loadTexture(texture: MDLTexture) throws -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: Renderer.device)
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] =
            [.origin: MTKTextureLoader.Origin.bottomLeft,
             .SRGB: false,
             .generateMipmaps: NSNumber(booleanLiteral: true)]

        let texture = try? textureLoader.newTexture(texture: texture,
                                                    options: textureLoaderOptions)
        return texture
    }

    static func loadTexture(imageName: String, origin: MTKTextureLoader.Origin = .topLeft) throws -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: Renderer.device)
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] =
            // TODO: WHAT THE FUCK? gltf textures are loading upside down you dumbass
            [.origin: origin,
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
