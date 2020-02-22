//
//  TileScene.swift
//  Highlands-iOS
//
//  Created by Scott Mehus on 2/18/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import Foundation
import MetalKit

class TileScene: Node {

//    private let water = Water(size: 50)
    let terrain = Terrain(textureName: "hills")

    func setupTile() {

//        terrain.position = SIMD3<Float>([0, 0, 0])
        //        terrain.rotation = float3(radians(fromDegrees: -20), 0, 0)
        add(childNode: terrain)
        terrain.setup(with: [0, 0, 0])

//        water.position.y = -9
//        water.rotation = [0, 0, radians(fromDegrees: -90)]
//        add(childNode: water)
        /*
         ground.tiling = 4
         ground.scale = [4, 1, 4]
         ground.position = float3(0, -0.03, 0)
         add(node: ground)
         */


        let count = 10
        let offset = 25

        let tree = Prop(type: .instanced(name: "treefir", instanceCount: count))
        add(childNode: tree)
//        physicsController.addStaticBody(node: tree)
        for i in 0..<count {
            var transform = Transform()
            transform.scale = [3.0, 3.0, 3.0]

            var position: SIMD3<Float>
            repeat {
                position = [Float(Int.random(in: -offset...offset)), 0, Float(Int.random(in: -offset...offset))]
            } while position.x > 2 && position.z > 2

            transform.position = position
            tree.updateBuffer(instance: i, transform: transform, textureID: 0)
        }

        let textureNames = ["rock1-color", "rock2-color", "rock3-color"]
        let morphTargetNames = ["rock1", "rock2", "rock3"]
        let rock = Prop(type: .morph(textures: textureNames, morphTargets: morphTargetNames, instanceCount: count))

        add(childNode: rock)
//        physicsController.addStaticBody(node: rock)
        for i in 0..<count {
            var transform = Transform()

            if i == 0 {
                transform.position = [0, 0, 3]
            } else {
                var position: SIMD3<Float>
                repeat {
                    position = [Float(Int.random(in: -offset...offset)), 0, Float(Int.random(in: -offset...offset))]
                } while position.x > 2 && position.z > 2

                transform.position = position
            }

            rock.updateBuffer(instance: i, transform: transform, textureID: .random(in: 0..<textureNames.count))
        }
    }
}

extension TileScene: Renderable {

    func generateTerrain(computeEncoder: MTLComputeCommandEncoder, uniforms: Uniforms) {
        terrain.compute(computeEncoder: computeEncoder, uniforms: uniforms)
    }

    func generateTerrainNormalMap(computeEncoder: MTLComputeCommandEncoder) {
        terrain.generateTerrainNormalMap(computeEncoder: computeEncoder)
    }

    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, terrainParams: TerrainParams, uniforms: Uniforms) {

        for child in children {
            guard let renderable = child as? Prop else { continue }

            renderable.patches = terrain.terrainPatches.1
            renderable.calculateHeight(computeEncoder: computeEncoder, heightMapTexture: terrain.heightMap, terrainParams: terrainParams, uniforms: uniforms, controlPointsBuffer: terrain.controlPointsBuffer)
        }
    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
        for child in children {
            guard let renderable = child as? Renderable else { fatalError() }

            renderable.render(renderEncoder: renderEncoder, uniforms: vertex)
        }
    }

    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, startingIndex: Int) {
        for child in children {
            guard let renderable = child as? Renderable else { fatalError() }

            renderable.renderShadow(renderEncoder: renderEncoder, uniforms: uniforms, startingIndex: startingIndex)
        }
    }

    func renderToTarget(with commandBuffer: MTLCommandBuffer) {

    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }

    func createTexturesBuffer() {

    }
}
