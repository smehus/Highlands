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

        // The vertex descriptor stride describes the number of bytes between the start of one vertex and the start of the next.
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 32)
        return vertexDescriptor
    }()

    let mesh: MTKMesh
    let submeshes: [Submesh]
    var tiling: UInt32 = 1
    let samplerState: MTLSamplerState?
    let debugBoundingBox: DebugBoundingBox
    let propType: ModelType
    private(set) var transforms: [Transform]
    let instanceCount: Int
    var instanceBuffer: MTLBuffer

    let shadowInstanceCount: Int
    var shadowTransforms: [Transform]
    var shadowInstanceBuffer: MTLBuffer

    var windingOrder: MTLWinding = .counterClockwise

    let heightCalculatePipelineState: MTLComputePipelineState
    let heightBuffer: MTLBuffer

    var patches: [Patch]!
    var currentPatch: Patch?

    var instanceStencilPlanes: [MTKMesh]
    var stencilPipeline: MTLRenderPipelineState

    init(type: ModelType) {

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




        instanceStencilPlanes = (0...instanceCount).map({ _ in
            let allocator = MTKMeshBufferAllocator(device: Renderer.device)
            let mdlMesh = MDLMesh(planeWithExtent: [2, 2, 2],
                                  segments: [1, 1],
                                  geometryType: .triangles,
                                  allocator: allocator)

            return try! MTKMesh(mesh: mdlMesh, device: Renderer.device)
        })

        let stencilPipelineDescriptor = MTLRenderPipelineDescriptor()
        stencilPipelineDescriptor.vertexFunction = Renderer.library!.makeFunction(name: "stencil_vertex")!
        stencilPipelineDescriptor.fragmentFunction = nil
        stencilPipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        stencilPipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(instanceStencilPlanes.first!.vertexDescriptor)
        stencilPipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        stencilPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8

        stencilPipeline = try! Renderer.device.makeRenderPipelineState(descriptor: stencilPipelineDescriptor)

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
        pointer.pointee.modelMatrix = transform.modelMatrix
        pointer.pointee.normalMatrix = transform.normalMatrix
        pointer.pointee.textureID = UInt32(textureID)




        // Set matrices for shadow instances
        var shadowPointer = shadowInstanceBuffer.contents().bindMemory(to: Instances.self, capacity: shadowTransforms.count)
        let startingPoint = instance * 6
        shadowTransforms[startingPoint] = transform

        shadowPointer = shadowPointer.advanced(by: startingPoint)
        shadowPointer.pointee.modelMatrix = transform.modelMatrix
        shadowPointer.pointee.viewportIndex = UInt32(0)

        for i in 1...5 {
            shadowTransforms[i + startingPoint] = transform
            shadowPointer = shadowPointer.advanced(by: 1)
            shadowPointer.pointee.modelMatrix = transform.modelMatrix
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

        for (index, _) in transforms.enumerated() {
            if index > transforms.startIndex {
                pointer = pointer.advanced(by: 1)
            }

            // transform
            transforms[index].position.y = pointer.pointee

            // shadow transform
            let shadowStartIndex = index  * 6

            for i in shadowStartIndex...shadowStartIndex + 5 {

                shadowTransforms[i].position.y = pointer.pointee
            }
        }


        // Update buffers

        var instancePointer = instanceBuffer.contents().bindMemory(to: Instances.self, capacity: transforms.count)
        var shadowInstancePointer = shadowInstanceBuffer.contents().bindMemory(to: Instances.self, capacity: shadowTransforms.count)

        // I need to rethink this logic
        for i in 0..<transforms.count {
            if i > transforms.startIndex {
                instancePointer = instancePointer.advanced(by: 1)
            }

            instancePointer.pointee.modelMatrix = transforms[i].modelMatrix
            instancePointer.pointee.normalMatrix = transforms[i].normalMatrix
        }


        for i in 0..<shadowTransforms.count {

            if i > shadowTransforms.startIndex {
                shadowInstancePointer = shadowInstancePointer.advanced(by: 1)
            }

            shadowInstancePointer.pointee.modelMatrix = shadowTransforms[i].modelMatrix
            shadowInstancePointer.pointee.normalMatrix = shadowTransforms[i].normalMatrix
        }
    }

    func patch(for location: SIMD3<Float>) -> Patch? {
        let foundPatches = patches.filter { (patch) -> Bool in
            let horizontal = patch.topLeft.x <= location.x && patch.topRight.x >= location.x
            let vertical = patch.topLeft.z >= location.z && patch.bottomLeft.z <= location.z

            return horizontal && vertical
        }

        //        print("**** patches found for position \(foundPatches.count)")
        guard let patch = foundPatches.first else {
            print(name)
            print("*** location \(location)")
            patches.forEach({ print("*** patches \($0)") })


            return nil
        }

        if let current = currentPatch, current != patch {
            //            print("*** UPDATE CURRENT PATCH \(patch)")
        }

        return patch
    }
}

extension Prop: Renderable {

    private enum RenderType {
        case main
        case stencil
    }

    func createTexturesBuffer() {
        for mesh in submeshes {
            mesh.createTexturesBuffer()
        }
    }



    func renderStencilBuffer(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms) {
        for (transform, plane) in zip(transforms, instanceStencilPlanes) {
            var uniforms = uniforms

            var planeTransform = Transform()
            planeTransform.position = transform.position
            planeTransform.scale = transform.scale
            planeTransform.rotation = [0, 0, radians(fromDegrees: -90)]

            uniforms.modelMatrix = worldTransform * planeTransform.modelMatrix

            renderEncoder.setRenderPipelineState(stencilPipeline)
            renderEncoder.setVertexBuffer(plane.vertexBuffers.first!.buffer, offset: 0, index: 0)

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            plane.submeshes.enumerated().forEach { (_, submesh) in
                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer.buffer,
                                                    indexBufferOffset: submesh.indexBuffer.offset)
            }
        }
    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
        renderEncoder.pushDebugGroup(name)
        render(renderEncoder: renderEncoder, uniforms: vertex, type: .main)
        renderEncoder.popDebugGroup()
    }

    private func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms, type: RenderType) {
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

            let typePipeline = type == .stencil ? modelSubmesh.stencilPipelineState : modelSubmesh.pipelineState
            renderEncoder.setRenderPipelineState(typePipeline!)

            // Check out character for why this is commented out
            //            if let baseColorIndex = modelSubmesh.baseColorIndex {
            //                renderEncoder.useResource(TextureController.textures[baseColorIndex].texture, usage: .read)
            //            }
            //
            //            if let normalIndex = modelSubmesh.normalIndex {
            //                renderEncoder.useResource(TextureController.textures[normalIndex].texture, usage: .read)
            //            }

            //            if let roughnessTexture = modelSubmesh.textures.roughness {
            //                renderEncoder.useResource(roughnessTexture, usage: .read)
            //            }

            renderEncoder.setFragmentBuffer(modelSubmesh.texturesBuffer, offset: 0, index: Int(BufferIndexTextures.rawValue))

            var material = modelSubmesh.material
            renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: Int(BufferIndexMaterials.rawValue))

            let submesh = modelSubmesh.mtkSubmesh
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
        uniforms.modelMatrix = worldTransform
        uniforms.normalMatrix = float3x3(normalFrom4x4: worldTransform)

        renderEncoder.setVertexBuffer(shadowInstanceBuffer, offset: 0, index: Int(BufferIndexInstances.rawValue))
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

        for (index, vertexBuffer) in mesh.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, index: index)
        }

        for modelSubmesh in submeshes {
            renderEncoder.setRenderPipelineState(modelSubmesh.shadowPipelineState)
            let submesh = modelSubmesh.mtkSubmesh

            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset,
                                                instanceCount: shadowInstanceCount)
        }
    }

    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, heightMapTexture: MTLTexture, terrainParams: TerrainParams, uniforms: Uniforms, controlPointsBuffer: MTLBuffer?) {

        for (index, transform) in transforms.enumerated() {
            let worldPosition = parent!.worldTransform * transform.modelMatrix
            var position = worldPosition.columns.3.xyz
            guard var patch = patch(for: position) else {
                print("⁉️⁉️⁉️⁉️ Couldn't find patch for \(name)"); return
            }

            var terrainParams = terrainParams
            var uniforms = uniforms
            var transformIndex = index

            computeEncoder.setComputePipelineState(heightCalculatePipelineState)
            computeEncoder.setBytes(&position, length: MemoryLayout<SIMD3<Float>>.size, index: 0)
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
