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
    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, heightMapTexture: MTLTexture, terrain: TerrainParams, uniforms: Uniforms, controlPointsBuffer: MTLBuffer?)
    func createTexturesBuffer()
}

extension Renderable {
    func renderToTarget(with commandBuffer: MTLCommandBuffer) { }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, heightMapTexture: MTLTexture, terrain: TerrainParams, uniforms: Uniforms, controlPointsBuffer: MTLBuffer?) { }
}

protocol ComputeHandler {
    func compute(computeEncoder: MTLComputeCommandEncoder, uniforms: Uniforms)
}
