//
//  Model.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

enum ModelError: Error {
    case missingVertexBuffer
}

class Prop: Node {

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
    var tiling: UInt32 = 1
    let samplerState: MTLSamplerState?
    let debugBoundingBox: DebugBoundingBox

    init(name: String, isGround: Bool = false) {
        let assetURL = Bundle.main.url(forResource: name, withExtension: "obj")
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let asset = MDLAsset(url: assetURL, vertexDescriptor: Prop.defaultVertexDescriptor, bufferAllocator: allocator)
        let mdlMesh = asset.object(at: 0) as! MDLMesh

        // Add tangent and bit tangent
        mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                tangentAttributeNamed: MDLVertexAttributeTangent,
                                bitangentAttributeNamed: MDLVertexAttributeBitangent)

        Prop.defaultVertexDescriptor = mdlMesh.vertexDescriptor
        let mesh = try! MTKMesh(mesh: mdlMesh, device: Renderer.device)
        self.mesh = mesh

        submeshes = mdlMesh.submeshes?.enumerated().compactMap {index, element in
            guard let submesh = element as? MDLSubmesh else { assertionFailure(); return nil }
            return Submesh(submesh: mesh.submeshes[index], mdlSubmesh: submesh, isGround: isGround)
        } ?? []

        samplerState = Prop.buildSamplerState()
        debugBoundingBox = DebugBoundingBox(boundingBox: mdlMesh.boundingBox)
        super.init()

        boundingBox = mdlMesh.boundingBox
    }

    private static func buildSamplerState() -> MTLSamplerState? {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.mipFilter = .linear
        descriptor.maxAnisotropy = 8
        return Renderer.device.makeSamplerState(descriptor: descriptor)
    }

    override func update(deltaTime: Float) {

    }
}

extension Prop: Renderable {


    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {

        var uniforms = vertex
        uniforms.modelMatrix = worldTransform
        uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        renderEncoder.setVertexBytes(&uniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(BufferIndexUniforms.rawValue))

        for (index, vertexBuffer) in mesh.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer.buffer,
                                          offset: 0, index: index)
        }

        renderEncoder.setFragmentBytes(&tiling, length: MemoryLayout<UInt32>.stride, index: 22)


        for modelSubmesh in submeshes {
            renderEncoder.setRenderPipelineState(modelSubmesh.pipelineState)
            renderEncoder.setFragmentTexture(modelSubmesh.textures.baseColor, index: Int(BaseColorTexture.rawValue))
            renderEncoder.setFragmentTexture(modelSubmesh.textures.normal, index: Int(NormalTexture.rawValue))
            renderEncoder.setFragmentTexture(modelSubmesh.textures.roughness, index: 2)

            var material = modelSubmesh.material
            renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: Int(BufferIndexMaterials.rawValue))

            guard let submesh = modelSubmesh.submesh else { continue }

            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
            
            if debugRenderBoundingBox {
                debugBoundingBox.render(renderEncoder: renderEncoder, uniforms: uniforms)
            }
        }

    }
}
