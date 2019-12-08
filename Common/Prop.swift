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
    case water

    var name: String {
        switch self {
        case .base(let name, _): return name
        case .ground(let name): return name
        case .morph(_, let targets, _): return targets.first!
        case .instanced(let name, _): return name
        case .water: return "Water"
        }
    }

    var vertexFunctionName: String {
        switch self {
        case .base, .instanced, .ground:
            return "vertex_main"
        case .morph:
            return "vertex_morph"
        case .water: return "vertex_water"
        }
    }

    var fragmentFunctionName: String {
        switch self {
        case .base, .instanced, .ground:
            return "fragment_main"
        case .morph:
            return "fragment_main"
        case .water: return "fragment_water"
        }
    }

    var isInstanced: Bool {
        switch self {
        case .morph, .instanced: return true
        default: return false
        }
    }

    var isTextureArray: Bool {
        switch self {
        case .morph: return true
        default: return false
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

    var textureOrigin: MTKTextureLoader.Origin {
        return .bottomLeft
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
    let propType: PropType
    private(set) var transforms: [Transform]
    let instanceCount: Int
    var instanceBuffer: MTLBuffer

    let shadowInstanceCount: Int
    var shadowTransforms: [Transform]
    var shadowInstanceBuffer: MTLBuffer

    var windingOrder: MTLWinding = .counterClockwise

    let heightCalculatePipelineState: MTLComputePipelineState
    let heightBuffer: MTLBuffer

    let patches: [Patch]
    var currentPatch: Patch?

    init(type: PropType) {

        self.propType = type
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

        shadowInstanceCount = type.instanceCount * 6
        shadowTransforms = Prop.buildTransforms(instanceCount: instanceCount * 6)
        shadowInstanceBuffer = Prop.buildInstanceBuffer(transforms: shadowTransforms)

        heightCalculatePipelineState = Character.buildComputePipelineState()

        var bytes: [Float] = transforms.map { _ in return 0.0 }
        heightBuffer = Renderer.device.makeBuffer(bytes: &bytes, length: MemoryLayout<Float>.size * type.instanceCount, options: .storageModeShared)!
//        heightBuffer = Renderer.device.makeBuffer(length: MemoryLayout<float3>.size * type.instanceCount, options: .storageModeShared)!

        let terrainPatches = Terrain.createControlPoints(patches: Terrain.patches,
                                              size: (width: Terrain.terrainParams.size.x,
                                                     height: Terrain.terrainParams.size.y))


        patches = terrainPatches.patches

        super.init()
        self.name = type.name
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
        let instances = transforms.enumerated().map { (index, transform) -> Instances in
            Instances(modelMatrix: transform.modelMatrix,
                      normalMatrix: transform.normalMatrix,
                      textureID: 0, viewportIndex: 0)
        }

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

    func updateBuffer(instance: Int, transform: Transform, textureID: Int) {
        transforms[instance] = transform

        var pointer = instanceBuffer.contents().bindMemory(to: Instances.self, capacity: transforms.count)
        pointer = pointer.advanced(by: instance)
        pointer.pointee.modelMatrix = transforms[instance].modelMatrix
        pointer.pointee.normalMatrix = transforms[instance].normalMatrix
        pointer.pointee.textureID = UInt32(textureID)


        // Set matrices for shadow instances
        var shadowPointer = shadowInstanceBuffer.contents().bindMemory(to: Instances.self, capacity: shadowTransforms.count)
        let startingPoint = instance * 6
        shadowPointer = shadowPointer.advanced(by: startingPoint)
        shadowPointer.pointee.modelMatrix = transforms[instance].modelMatrix
        shadowPointer.pointee.viewportIndex = UInt32(0)
        for i in 1...6 {
            shadowPointer = shadowPointer.advanced(by: 1)
            shadowPointer.pointee.modelMatrix = transforms[instance].modelMatrix
            shadowPointer.pointee.viewportIndex = UInt32(i)
        }
    }

    // Update shadow Buffer
    func updateShadowBuffer(transformIndex: Int, viewPortIndex: Int) {
        var pointer = shadowInstanceBuffer.contents().bindMemory(to: Instances.self, capacity: shadowTransforms.count)
        pointer = pointer.advanced(by: transformIndex + viewPortIndex)
        pointer.pointee.viewportIndex = UInt32(viewPortIndex)
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

        var pointer = heightBuffer.contents().bindMemory(to: Float.self, capacity: transforms.count)
        transforms[0].position.y = pointer.pointee

        var instancePointer = instanceBuffer.contents().bindMemory(to: Instances.self, capacity: transforms.count)
        instancePointer.pointee.modelMatrix = transforms.first!.modelMatrix
        instancePointer.pointee.normalMatrix = transforms.first!.normalMatrix

        for i in 1..<transforms.count {
            pointer = pointer.advanced(by: 1)
            transforms[i].position.y = pointer.pointee

            
            // Update buffer for renderer
            instancePointer = instancePointer.advanced(by: 1)
            instancePointer.pointee.modelMatrix = transforms[i].modelMatrix
            instancePointer.pointee.normalMatrix = transforms[i].normalMatrix
        }
    }

    func patch(for location: float3) -> Patch? {
        let foundPatches = patches.filter { (patch) -> Bool in
            let horizontal = patch.topLeft.x < location.x && patch.topRight.x > location.x
            let vertical = patch.topLeft.z > location.z && patch.bottomLeft.z < location.z

            return horizontal && vertical
        }

        //        print("**** patches found for position \(foundPatches.count)")
        guard let patch = foundPatches.first else { return nil }

        if let current = currentPatch, current != patch {
//            print("*** UPDATE CURRENT PATCH \(patch)")
        }

        return patch
    }
}

extension Prop: Renderable {

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
//        renderEncoder.setFrontFacing(windingOrder)

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


    // Instanced trees: Need to add the number of cube map faces by the number of instances?
    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, startingIndex: Int) {

        var uniforms = uniforms
        uniforms.modelMatrix = modelMatrix
        uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

        renderEncoder.setVertexBuffer(shadowInstanceBuffer, offset: 0, index: Int(BufferIndexInstances.rawValue))
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

        for (index, vertexBuffer) in mesh.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, index: index)
        }

        for modelSubmesh in submeshes {
            renderEncoder.setRenderPipelineState(modelSubmesh.shadowPipelineState)
            let submesh = modelSubmesh.submesh!

            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset,
                                                instanceCount: shadowInstanceCount)
        }
    }

    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, heightMapTexture: MTLTexture, terrain: TerrainParams, uniforms: Uniforms, controlPointsBuffer: MTLBuffer?) {

        for (index, transform) in transforms.enumerated() {
            var position = transform.modelMatrix.columns.3.xyz
            guard var patch = patch(for: position) else { return }


            var terrainParams = terrain
            var uniforms = uniforms
            var transformIndex = index

            computeEncoder.setComputePipelineState(heightCalculatePipelineState)
            computeEncoder.setBytes(&position, length: MemoryLayout<float3>.size, index: 0)
            computeEncoder.setBuffer(heightBuffer, offset: 0, index: 1)
            computeEncoder.setBytes(&terrainParams, length: MemoryLayout<TerrainParams>.stride, index: 2)
            computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 3)
            computeEncoder.setBuffer(controlPointsBuffer, offset: 0, index: 4)
            computeEncoder.setBytes(&patch, length: MemoryLayout<Patch>.stride, index: 5)
            computeEncoder.setBytes(&transformIndex, length: MemoryLayout<Int>.size, index: 6)
            computeEncoder.setTexture(heightMapTexture, index: 0)

            computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                                threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
        }
    }
}
