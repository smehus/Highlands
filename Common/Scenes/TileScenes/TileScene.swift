//
//  TileScene.swift
//  Highlands-iOS
//
//  Created by Scott Mehus on 2/18/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import Foundation


struct TileScene: Node {

    var name: String {
        return "TileScene"
    }

    private let water = Water(size: 500)
    let terrain = Terrain(textureName: "hills")

    init(sceneSize: CGSize) {
        setupTile()
    }

    func setupTile() {


                terrain.position = SIMD3<Float>([0, 0, 0])

        water.position.y = -4
        water.rotation = [0, 0, radians(fromDegrees: -90)]
        add(node: water)


        let count = 50
        let offset = 100

        let tree = Prop(type: .instanced(name: "treefir", instanceCount: count))
        add(node: tree)
        physicsController.addStaticBody(node: tree)
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

        add(node: rock)
        physicsController.addStaticBody(node: rock)
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

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {

    }

    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, startingIndex: Int) {

    }

    func renderToTarget(with commandBuffer: MTLCommandBuffer) {

    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }

    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, heightMapTexture: MTLTexture, terrain: TerrainParams, uniforms: Uniforms, controlPointsBuffer: MTLBuffer?) {

    }

    func createTexturesBuffer() {

    }
}
