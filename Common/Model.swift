//
//  Model.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

class Model: Node {

    static var defaultVertexDescriptor: MDLVertexDescriptor = {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[Int(Position.rawValue)] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)


        vertexDescriptor.attributes[Int(Normal.rawValue)] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .float3,
                                                            offset: 12,
                                                            bufferIndex: 0)

        vertexDescriptor.attributes[Int(UV.rawValue)] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                                           format: .float2,
                                                                           offset: 24,
                                                                           bufferIndex: 0)

        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 32)
        return vertexDescriptor
    }()

    let mesh: MTKMesh
    let submeshes: [Submesh]
    let vertexBuffer: MTLBuffer
    let pipelineState: MTLRenderPipelineState
    var tiling: UInt32 = 1
    let samplerState: MTLSamplerState?

    init(name: String) {
        let assetURL = Bundle.main.url(forResource: name, withExtension: "obj")
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let asset = MDLAsset(url: assetURL, vertexDescriptor: Model.defaultVertexDescriptor, bufferAllocator: allocator)
        let mdlMesh = asset.object(at: 0) as! MDLMesh

        let mesh = try! MTKMesh(mesh: mdlMesh, device: Renderer.device)
        self.mesh = mesh

        vertexBuffer = mesh.vertexBuffers[0].buffer

        submeshes = mdlMesh.submeshes?.enumerated().compactMap {index, element in
            guard let submesh = element as? MDLSubmesh else { return nil }
            return Submesh(submesh: mesh.submeshes[index], mdlSubmesh: submesh)
        } ?? []

        pipelineState = Model.buildPipelineState(vertexDescriptor: mdlMesh.vertexDescriptor)
        samplerState = Model.buildSamplerState()
        super.init()
    }

    private static func buildSamplerState() -> MTLSamplerState? {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.mipFilter = .linear
        descriptor.maxAnisotropy = 8
        return Renderer.device.makeSamplerState(descriptor: descriptor)
    }

    private static func buildPipelineState(vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        let library = Renderer.library
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")

        let pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat

        do {
            pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError(error.localizedDescription)
        }

        return pipelineState
    }

}
