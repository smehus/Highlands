//
//  Renderable.swift
//  Highlands
//
//  Created by Scott Mehus on 12/21/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

enum RenderType {
    case main
    case stencil
}

protocol Renderable {
    var name: String { get }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms)

    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, startingIndex: Int)

    func renderToTarget(with commandBuffer: MTLCommandBuffer, camera: Camera, lights: [Light], uniforms: Uniforms, renderables: [Renderable])

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)

    func generateTerrain(computeEncoder: MTLComputeCommandEncoder, uniforms: Uniforms)

    func generateTerrainNormalMap(computeEncoder: MTLComputeCommandEncoder)

    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, terrainParams: TerrainParams, uniforms: Uniforms)

    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, heightMapTexture: MTLTexture, terrainParams: TerrainParams, uniforms: Uniforms, controlPointsBuffer: MTLBuffer?)

    func renderStencilBuffer(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms)

    func createTexturesBuffer()
}

extension Renderable {
    func renderStencilBuffer(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms) { }
    func renderToTarget(with commandBuffer: MTLCommandBuffer, camera: Camera, lights: [Light], uniforms: Uniforms, renderables: [Renderable]) {}
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, heightMapTexture: MTLTexture, terrainParams: TerrainParams, uniforms: Uniforms, controlPointsBuffer: MTLBuffer?) { }
    func generateTerrain(computeEncoder: MTLComputeCommandEncoder, uniforms: Uniforms) { }
    func generateTerrainNormalMap(computeEncoder: MTLComputeCommandEncoder) { }
    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, terrainParams: TerrainParams, uniforms: Uniforms) { }
}

protocol ComputeHandler {
    func compute(computeEncoder: MTLComputeCommandEncoder, uniforms: Uniforms)
}
