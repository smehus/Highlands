//
//  TileScene.swift
//  Highlands-iOS
//
//  Created by Scott Mehus on 2/18/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import Foundation
import MetalKit

protocol TileSceneDelegate: class {
    func physicsControllAdd(_ node: Node)
}

class TileScene: Node {

    weak var delegate: TileSceneDelegate?

    let terrain = Terrain(textureName: "terrain1")
    private let water = Water(size: 50)


    func setupTile() {

//        terrain.position = SIMD3<Float>([0, 0, 0])
        //        terrain.rotation = float3(radians(fromDegrees: -20), 0, 0)
        add(childNode: terrain)
        terrain.setup(with: [0, 0, 0])

        water.position.y = -6
        water.rotation = [0, 0, radians(fromDegrees: -90)]
        add(childNode: water)
        /*
         ground.tiling = 4
         ground.scale = [4, 1, 4]
         ground.position = float3(0, -0.03, 0)
         add(node: ground)
         */

        #if (iOS)
            let text = Text()
            add(childNode: text)
        #endif

        let count = 10
        let offset = 25
//
        let tree = Prop(type: .instanced(name: "treefir", instanceCount: 1))
        add(childNode: tree)

        var t = Transform()
        t.scale = [3.0, 3.0, 3.0]
        t.position = [0, 0, -8]
        tree.updateBuffer(instance: 0, transform: t, textureID: 0)

//        physicsController.addStaticBody(node: tree)
        for i in 0..<count {
//            var transform = Transform()
//            transform.scale = [3.0, 3.0, 3.0]
//
//            var position: SIMD3<Float>
//            repeat {
//                position = [Float(Int.random(in: -offset...offset)), 0, Float(Int.random(in: -offset...offset))]
//            } while position.x > 2 && position.z > 2
//
//            transform.position = position
//            tree.updateBuffer(instance: i, transform: transform, textureID: 0)
        }

//        let textureNames = ["rock1-color", "rock2-color", "rock3-color"]
//        let morphTargetNames = ["rock1", "rock2", "rock3"]
//        let rock = Prop(type: .morph(textures: textureNames, morphTargets: morphTargetNames, instanceCount: count))

//        add(childNode: rock)
////        physicsController.addStaticBody(node: rock)
//        for i in 0..<count {
//            var transform = Transform()
//
//            if i == 0 {
//                transform.position = [0, 0, 3]
//            } else {
//                var position: SIMD3<Float>
//                repeat {
//                    position = [Float(Int.random(in: -offset...offset)), 0, Float(Int.random(in: -offset...offset))]
//                } while position.x > 2 && position.z > 2
//
//                transform.position = position
//            }
//
//            rock.updateBuffer(instance: i, transform: transform, textureID: .random(in: 0..<textureNames.count))
//        }


        let box = Prop(type: .instanced(name: "wooden_box", instanceCount: 2))
        add(childNode: box)

        // Shadows only work correctly with instanced props right now.
        let transform = Transform()
        transform.position = [0, 0, 4]
        box.updateBuffer(instance: 0, transform: transform, textureID: 0)

        let transform2 = Transform()
        transform2.position = [8, 0, 2]
        box.updateBuffer(instance: 1, transform: transform2, textureID: 0)
        delegate?.physicsControllAdd(box)
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

        for case let renderable as Renderable in children {
            if let prop = renderable as? Prop {
                prop.patches = terrain.terrainPatches.1
            }

            renderable.calculateHeight(computeEncoder: computeEncoder, heightMapTexture: terrain.heightMap, terrainParams: terrainParams, uniforms: uniforms, controlPointsBuffer: terrain.controlPointsBuffer)
        }
    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
        for child in children {
            guard let renderable = child as? Renderable else { continue }

            renderable.render(renderEncoder: renderEncoder, uniforms: vertex)
        }
    }

    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, startingIndex: Int) {
        for child in children {
            guard let renderable = child as? Renderable else { continue }

            renderable.renderShadow(renderEncoder: renderEncoder, uniforms: uniforms, startingIndex: startingIndex)
        }
    }

    func renderToTarget(with commandBuffer: MTLCommandBuffer, camera: Camera, lights: [Light], uniforms: Uniforms, renderables: [Renderable], shadowColorTexture: MTLTexture, shadowDepthTexture: MTLTexture, player: Node) {
        for case let child as Renderable in children {
            var nodes = children.compactMap { $0 as? Renderable }
            nodes.append(contentsOf: renderables)
            child.renderToTarget(with: commandBuffer, camera: camera, lights: lights, uniforms: uniforms, renderables: nodes, shadowColorTexture: shadowColorTexture, shadowDepthTexture: shadowDepthTexture, player: player)
        }
    }

    func renderStencilBuffer(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms) {
        for child in children {
            guard let renderable = child as? Renderable else { fatalError() }

            renderable.renderStencilBuffer(renderEncoder: renderEncoder, uniforms: uniforms)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        for case let renderable as Renderable in children {
            renderable.mtkView(view, drawableSizeWillChange: size)
        }
    }

    func createTexturesBuffer() {
        for case let renderable as Renderable in children {
            renderable.createTexturesBuffer()
        }
    }
}
