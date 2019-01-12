//
//  Model.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

enum PropType {
    case base(name: String, lighting: Bool)
    case instanced(name: String, instanceCount: Int)
    case ground(name: String)
    case morph(textures: [String], morphTargets: [String], instanceCount: Int)

    var name: String {
        switch self {
        case .base(let name, _): return name
        case .ground(let name): return name
        case .morph(_, let targets, _): return targets.first!
        case .instanced(let name, _): return name
        }
    }

    var vertexFunctionName: String {
        switch self {
        case .base, .instanced, .ground:
            return "vertex_main"
        case .morph:
            return "vertex_morph"
        }
    }

    var fragmentFunctionName: String {
        switch self {
        case .base, .instanced, .ground:
            return "fragment_main"
        case .morph:
            return "fragment_main"
        }
    }

    var instanceCount: Int {
        switch self {
        case .morph(_, _, let count):
            return count
        case .instanced(_, let instanceCount):
            return instanceCount
        default:
            return 1
        }
    }

    var isGround: Bool {
        switch self {
        case .ground: return true
        default: return false
        }
    }

    var blending: Bool {
        return false
    }

    var lighting: Bool {
        switch self {
        case .base(_, let lighting): return lighting
        default: return true
        }
    }
}

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

        // The vertex descriptor stride describes the number of bytes between the start of one vertex and the start of the next.
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 32)
        return vertexDescriptor
    }()

    let mesh: MTKMesh
    let submeshes: [Submesh]
    var tiling: UInt32 = 1
    let samplerState: MTLSamplerState?
    let debugBoundingBox: DebugBoundingBox

    private var transforms: [Transform]
    let instanceCount: Int
    var instanceBuffer: MTLBuffer

    init(type: PropType) {
        // MDLMesh: Load model from bundle
        let mdlMesh = Prop.loadMesh(name: type.name)
        mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                tangentAttributeNamed: MDLVertexAttributeTangent,
                                bitangentAttributeNamed: MDLVertexAttributeBitangent)

        Prop.defaultVertexDescriptor = mdlMesh.vertexDescriptor
        let mtkMesh = try! MTKMesh(mesh: mdlMesh, device: Renderer.device)
        mesh = mtkMesh

        submeshes = mdlMesh.submeshes?.enumerated().compactMap { index, element in
            guard let submesh = element as? MDLSubmesh else { assertionFailure(); return nil }
            return Submesh(submesh: mtkMesh.submeshes[index], mdlSubmesh: submesh, type: type)
            } ?? []

        samplerState = Prop.buildSamplerState()
        debugBoundingBox = DebugBoundingBox(boundingBox: mdlMesh.boundingBox)

        instanceCount = type.instanceCount
        transforms = Prop.buildTransforms(instanceCount: instanceCount)
        instanceBuffer = Prop.buildInstanceBuffer(transforms: transforms)

        super.init()

        boundingBox = mdlMesh.boundingBox
    }

//    init(name: String, vertexFunction: String = "vertex_main", fragmentFunction: String = "fragment_main", instanceCount: Int = 1) {
//
//        let mdlMesh = Prop.loadMesh(name: name)
//        // Add tangent and bit tangent
//        mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
//                                tangentAttributeNamed: MDLVertexAttributeTangent,
//                                bitangentAttributeNamed: MDLVertexAttributeBitangent)
//
//        Prop.defaultVertexDescriptor = mdlMesh.vertexDescriptor
//        let mesh = try! MTKMesh(mesh: mdlMesh, device: Renderer.device)
//        self.mesh = mesh
//
//        submeshes = mdlMesh.submeshes?.enumerated().compactMap {index, element in
//            guard let submesh = element as? MDLSubmesh else { assertionFailure(); return nil }
//            return Submesh(base: (mesh.submeshes[index], submesh, vertexFunction, fragmentFunction),
//                           isGround: name == "large-plane",
//                           blending: name == "window")
//        } ?? []
//
//        samplerState = Prop.buildSamplerState()
//        debugBoundingBox = DebugBoundingBox(boundingBox: mdlMesh.boundingBox)
//
//        self.instanceCount = instanceCount
//        transforms = Prop.buildTransforms(instanceCount: instanceCount)
//        instanceBuffer = Prop.buildInstanceBuffer(transforms: transforms)
//
//        super.init()
//
//        boundingBox = mdlMesh.boundingBox
//
//    }

    static func loadMesh(name: String) -> MDLMesh {
        let assetURL = Bundle.main.url(forResource: name, withExtension: "obj")
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let asset = MDLAsset(url: assetURL, vertexDescriptor: Prop.defaultVertexDescriptor, bufferAllocator: allocator)
        return asset.object(at: 0) as! MDLMesh
    }

    static func buildInstanceBuffer(transforms: [Transform]) -> MTLBuffer {
        let instances = transforms.map { Instances(modelMatrix: $0.modelMatrix, normalMatrix: $0.normalMatrix) }

        guard
            let instanceBuffer = Renderer.device
                .makeBuffer(bytes: instances, length: MemoryLayout<Instances>.stride * instances.count)
        else {
            fatalError()
        }

        return instanceBuffer
    }

    static func buildTransforms(instanceCount: Int) -> [Transform] {
        return [Transform](repeatElement(Transform(), count: instanceCount))
    }

    func updateBuffer(instance: Int, transform: Transform) {
        transforms[instance] = transform

        var pointer = instanceBuffer.contents().bindMemory(to: Instances.self, capacity: transforms.count)
        pointer = pointer.advanced(by: instance)
        pointer.pointee.modelMatrix = transforms[instance].modelMatrix
        pointer.pointee.normalMatrix = transforms[instance].normalMatrix
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
        uniforms.normalMatrix = float3x3(normalFrom4x4: worldTransform)

        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        renderEncoder.setVertexBytes(&uniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(BufferIndexUniforms.rawValue))

        renderEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: Int(BufferIndexInstances.rawValue))
        for (index, vertexBuffer) in mesh.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, index: index)
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
                                                indexBufferOffset: submesh.indexBuffer.offset,
                                                instanceCount: instanceCount)
            
            if debugRenderBoundingBox {
                debugBoundingBox.render(renderEncoder: renderEncoder, uniforms: uniforms)
            }
        }

    }
}
