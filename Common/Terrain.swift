//
//  Terrain.swift
//  Highlands
//
//  Created by Scott Mehus on 8/31/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

import Foundation
import MetalKit

class Terrain: Node {

    static let maxTessellation: Int = {
        return 16
    }()

    static let patches = (horizontal: 7, vertical: 7)
    static var patchCount: Int {
        return patches.horizontal * patches.vertical
    }

    var terrainParams = TerrainParams(size: [500, 500], height: 50, maxTessellation: UInt32(maxTessellation))
    private var edgeFactors: [Float] = [4]
    private var insideFactors: [Float] = [4]
    private var controlPointsBuffer: MTLBuffer?
    private var tessellationPipelineState: MTLComputePipelineState
    private var renderPipelineState: MTLRenderPipelineState

    let heightMap: MTLTexture
    private let cliffTexture: MTLTexture
    private let snowTexture: MTLTexture
    private let grassTexture: MTLTexture

    override var modelMatrix: float4x4 {
        let translationMatrix = float4x4(translation: position)
        let rotationMatrix = float4x4(rotation: rotation)
        return translationMatrix * rotationMatrix
    }

    lazy var tessellationFactorsBuffer: MTLBuffer! = {
        let count = Terrain.patchCount * (4 + 2)
        let size = count * MemoryLayout<Float>.size / 2
        return Renderer.device.makeBuffer(length: size, options: .storageModePrivate)
    }()

    init(textureName: String) {
        renderPipelineState = Terrain.buildRenderPipelineState()
        tessellationPipelineState = Terrain.buildComputePipelineState()

        do {
            let textureLoader = MTKTextureLoader(device: Renderer.device)
            heightMap = try textureLoader.newTexture(name: textureName, scaleFactor: 1.0,
                                                bundle: Bundle.main, options: nil)
            cliffTexture = try textureLoader.newTexture(name: "cliff-color", scaleFactor: 1.0,
                                                bundle: Bundle.main, options: nil)
            snowTexture = try textureLoader.newTexture(name: "snow-color", scaleFactor: 1.0,
                                                bundle: Bundle.main, options: nil)
            grassTexture = try textureLoader.newTexture(name: "grass-color", scaleFactor: 1.0,
                                                bundle: Bundle.main, options: nil)

        } catch {
            fatalError(error.localizedDescription)
        }

        super.init()

        let controlPoints = createControlPoints(patches: Terrain.patches,
                                                size: (width: terrainParams.size.x,
                                                       height: terrainParams.size.y))
        controlPointsBuffer = Renderer.device.makeBuffer(bytes: controlPoints,
                                                         length: MemoryLayout<float3>.stride * controlPoints.count)


    }
}

extension Terrain {

    static func buildComputePipelineState() -> MTLComputePipelineState {
        guard let kernelFunction = Renderer.library?.makeFunction(name: "tessellation_main") else {
            fatalError("Tessellation shader function not found")
        }

        return try! Renderer.device.makeComputePipelineState(function: kernelFunction)
    }

    static func buildRenderPipelineState() -> MTLRenderPipelineState {
      let descriptor = MTLRenderPipelineDescriptor()
      descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
      descriptor.depthAttachmentPixelFormat = .depth32Float

      let vertexFunction = Renderer.library?.makeFunction(name: "vertex_terrain")
      let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_terrain")
      descriptor.vertexFunction = vertexFunction
      descriptor.fragmentFunction = fragmentFunction

      let vertexDescriptor = MTLVertexDescriptor()
      vertexDescriptor.attributes[0].format = .float3
      vertexDescriptor.attributes[0].offset = 0
      vertexDescriptor.attributes[0].bufferIndex = 0

      vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint
      vertexDescriptor.layouts[0].stride = MemoryLayout<float3>.stride
      descriptor.vertexDescriptor = vertexDescriptor

      descriptor.tessellationFactorStepFunction = .perPatch
      descriptor.maxTessellationFactor = maxTessellation
      descriptor.tessellationPartitionMode = .pow2

        return try! Renderer.device.makeRenderPipelineState(descriptor: descriptor)
    }
}

extension Terrain {
    /**
     Create control points
     - Parameters:
     - patches: number of patches across and down
     - size: size of plane
     - Returns: an array of patch control points. Each group of four makes one patch.
     **/
    func createControlPoints(patches: (horizontal: Int, vertical: Int),
                             size: (width: Float, height: Float)) -> [float3] {

        var points: [float3] = []
        // per patch width and height
        let width = 1 / Float(patches.horizontal)
        let height = 1 / Float(patches.vertical)

        for j in 0..<patches.vertical {
            let row = Float(j)
            for i in 0..<patches.horizontal {
                let column = Float(i)
                let left = width * column
                let bottom = height * row
                let right = width * column + width
                let top = height * row + height

                points.append([left, 0, top])
                points.append([right, 0, top])
                points.append([right, 0, bottom])
                points.append([left, 0, bottom])
            }
        }
        // size and convert to Metal coordinates
        // eg. 6 across would be -3 to + 3
        points = points.map {
            [$0.x * size.width - size.width / 2,
             0,
             $0.z * size.height - size.height / 2]
        }
        return points
    }
}


extension Terrain: ComputeHandler {
    func compute(computeEncoder: MTLComputeCommandEncoder, uniforms: Uniforms) {

        computeEncoder.setComputePipelineState(tessellationPipelineState)
        computeEncoder.setBytes(&edgeFactors,
                                length: MemoryLayout<Float>.size * edgeFactors.count,
                                index: 0)
        computeEncoder.setBytes(&insideFactors,
                                length: MemoryLayout<Float>.size * insideFactors.count,
                                index: 1)
        computeEncoder.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
        var cameraPosition = uniforms.viewMatrix.columns.3
        computeEncoder.setBytes(&cameraPosition,
                                length: MemoryLayout<float4>.stride,
                                index: 3)
        var matrix = modelMatrix
        computeEncoder.setBytes(&matrix,
                                length: MemoryLayout<float4x4>.stride,
                                index: 4)
        computeEncoder.setBuffer(controlPointsBuffer, offset: 0, index: 5)
        computeEncoder.setBytes(&terrainParams,
                                length: MemoryLayout<TerrainParams>.stride,
                                index: 6)

        let width = min(Terrain.patchCount,
                        tessellationPipelineState.threadExecutionWidth)
        computeEncoder.dispatchThreadgroups(MTLSizeMake(Terrain.patchCount, 1, 1),
                                            threadsPerThreadgroup: MTLSizeMake(width, 1, 1))

    }
}

extension Terrain: Renderable {
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {

        renderEncoder.pushDebugGroup("Terrain")
        renderEncoder.setCullMode(.none)
        var uniforms = vertex

        uniforms.modelMatrix = modelMatrix

        var mvp = uniforms.projectionMatrix * uniforms.viewMatrix * modelMatrix

        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        renderEncoder.setVertexBuffer(controlPointsBuffer, offset: 0, index: 0)
        renderEncoder.setTriangleFillMode(.fill)
        renderEncoder.setTessellationFactorBuffer(tessellationFactorsBuffer, offset: 0, instanceStride: 0)
        renderEncoder.setVertexTexture(heightMap, index: 0)
        renderEncoder.setVertexBytes(&terrainParams, length: MemoryLayout<TerrainParams>.stride, index: 6)

        renderEncoder.setFragmentTexture(cliffTexture, index: Int(TerrainTextureBase.rawValue))
        renderEncoder.setFragmentTexture(snowTexture, index: Int(TerrainTextureMiddle.rawValue))
        renderEncoder.setFragmentTexture(grassTexture, index: Int(TerrainTextureTop.rawValue))

        renderEncoder.drawPatches(numberOfPatchControlPoints: 4,
                                  patchStart: 0,
                                  patchCount: Terrain.patchCount,
                                  patchIndexBuffer: nil,
                                  patchIndexBufferOffset: 0,
                                  instanceCount: 1,
                                  baseInstance: 0)

        renderEncoder.popDebugGroup()

    }


    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, startingIndex: Int) { }

}
