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
    static var heap: MTLHeap?
    static var textures: [TextureWrapper] = []
    static var heapTextures: [MTLTexture] = []

    static func addTexture(texture: TextureWrapper?) -> Int? {
        guard let texture = texture else { return nil }

        TextureController.textures.append(texture)
        return TextureController.textures.count - 1
    }

    static func buildHeap() -> MTLHeap? {
        let heapDescriptor = MTLHeapDescriptor()

         let descriptors = textures.map { texture in
            MTLTextureDescriptor.descriptor(from: texture.texture)
         }
         let sizeAndAligns = descriptors.map {
           Renderer.device.heapTextureSizeAndAlign(descriptor: $0)
         }
         heapDescriptor.size = sizeAndAligns.reduce(0) {
           $0 + $1.size - ($1.size & ($1.align - 1)) + $1.align
         }
         if heapDescriptor.size == 0 {
           return nil
         }

        guard let heap = Renderer.device.makeHeap(descriptor: heapDescriptor) else { fatalError() }

        let heapTextures = descriptors.map { descriptor -> MTLTexture in
          descriptor.storageMode = heapDescriptor.storageMode
          return heap.makeTexture(descriptor: descriptor)!
        }

        guard
          let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
          let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            fatalError()
          }

        zip(textures, heapTextures).forEach { (texture, heapTexture) in
            var region = MTLRegionMake2D(0, 0, texture.texture.width, texture.texture.height)
            for level in 0..<texture.texture.mipmapLevelCount {
                for slice in 0..<texture.texture.arrayLength {
                    blitEncoder.copy(from: texture.texture,
                               sourceSlice: slice,
                               sourceLevel: level,
                               sourceOrigin: region.origin,
                               sourceSize: region.size,
                               to: heapTexture,
                               destinationSlice: slice,
                               destinationLevel: level,
                               destinationOrigin: region.origin)
            }
            region.size.width /= 2
            region.size.height /= 2
          }
        }
        blitEncoder.endEncoding()
        commandBuffer.commit()
        TextureController.heapTextures = heapTextures

        return heap
    }
}

// TODO: - can probably just pull this from textures?
extension MTLTextureDescriptor {
    static func descriptor(from texture: MTLTexture) -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = texture.textureType
        descriptor.pixelFormat = texture.pixelFormat
        descriptor.width = texture.width
        descriptor.height = texture.height
        descriptor.depth = texture.depth
        descriptor.mipmapLevelCount = texture.mipmapLevelCount
        descriptor.arrayLength = texture.arrayLength
        descriptor.sampleCount = texture.sampleCount
        descriptor.cpuCacheMode = texture.cpuCacheMode
        descriptor.usage = texture.usage
        descriptor.storageMode = texture.storageMode
        return descriptor
    }
}
