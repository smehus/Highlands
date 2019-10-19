//
//  Renderable.swift
//  Highlands
//
//  Created by Scott Mehus on 12/21/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

protocol Renderable {
    var name: String { get }
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms)
    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, startingIndex: Int)
    func renderToTarget(with commandBuffer: MTLCommandBuffer)
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    func calculateHeight(commandBuffer: MTLCommandBuffer, heightMapTexture: MTLTexture, terrain: TerrainParams, uniforms: Uniforms)
}

extension Renderable {
    func renderToTarget(with commandBuffer: MTLCommandBuffer) { }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    func calculateHeight(commandBuffer: MTLCommandBuffer, heightMapTexture: MTLTexture, terrain: TerrainParams, uniforms: Uniforms) { }
}

protocol ComputeHandler {
    func compute(computeEncoder: MTLComputeCommandEncoder, uniforms: Uniforms)
}
