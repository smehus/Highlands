

import MetalKit

class Morph: Node {
    let instanceCount: Int
    let instanceBuffer: MTLBuffer
    let pipelineState: MTLRenderPipelineState

    let morphTargetCount: Int
    let textureCount: Int

    let vertexBuffer: MTLBuffer
    let submesh: MTKSubmesh?

    static let mdlVertexDescriptor: MDLVertexDescriptor = {
        let vertexDescriptor = MDLVertexDescriptor()
        var offset = 0
        let packedFloat3Size = MemoryLayout<Float>.stride * 3

        vertexDescriptor.attributes[Int(Position.rawValue)] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: offset, bufferIndex: 0)
        offset += packedFloat3Size

        vertexDescriptor.attributes[Int(Normal.rawValue)] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: offset, bufferIndex: 0)
        offset += packedFloat3Size

        vertexDescriptor.attributes[Int(UV.rawValue)] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: offset, bufferIndex: 0)
        offset += MemoryLayout<float2>.stride

        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)

        return vertexDescriptor
    }()

    static let mtlVertexDescriptor: MTLVertexDescriptor = {
        return MTKMetalVertexDescriptorFromModelIO(Morph.mdlVertexDescriptor)!
    }()

    let baseColorTexture: MTLTexture?

    init(name: String,
         instanceCount: Int = 1,
         textureNames: [String] = [],
         morphTargetNames: [String] = []
        ) {

        morphTargetCount = morphTargetNames.count
        textureCount = textureNames.count

        // load up the first morph target into a buffer
        // assume only one vertex buffer and one material submesh for simplicity
        guard let mdlMesh = Morph.loadMesh(name: morphTargetNames[0]) else {
            fatalError("morph target not loaded")
        }

        guard let mesh = try? MTKMesh(mesh: mdlMesh, device: Renderer.device) else {
            fatalError()
        }

        submesh = Morph.loadSubmesh(mesh: mesh)
        vertexBuffer = mesh.vertexBuffers[0].buffer

        // create the pipeline state
        let library = Renderer.library
        guard let vertexFunction = library?.makeFunction(name: "vertex_morph"),
            let fragmentFunction = library?.makeFunction(name: "fragment_morph") else {
                fatalError("failed to create functions")
        }
        pipelineState = Morph.makePipelineState(vertex: vertexFunction,
                                                 fragment: fragmentFunction)

        // load the instances
        self.instanceCount = instanceCount
        instanceBuffer = Morph.buildInstanceBuffer(instanceCount: instanceCount)

        // load the texture
        do {
            baseColorTexture = try Morph.loadTexture(imageName: textureNames[0])
        } catch {
            fatalError(error.localizedDescription)
        }
        super.init()

        // initialize the instance buffer in case there is only one instance
        // (there is no array of Transforms in this class)
        updateBuffer(instance: 0, transform: Transform())
        self.name = name
    }

    static func loadSubmesh(mesh: MTKMesh) -> MTKSubmesh {
        guard let submesh = mesh.submeshes.first else {
            fatalError("No submesh found")
        }
        return submesh
    }

    static func buildInstanceBuffer(instanceCount: Int) -> MTLBuffer {
        guard let instanceBuffer =
            Renderer.device.makeBuffer(length: MemoryLayout<MorphInstance>.stride * instanceCount,
                                       options: []) else {
                                        fatalError("Failed to create instance buffer")
        }
        return instanceBuffer
    }

    func updateBuffer(instance: Int, transform: Transform) {
        var pointer =
            instanceBuffer.contents().bindMemory(to: MorphInstance.self,
                                                 capacity: instanceCount)
        pointer = pointer.advanced(by: instance)
        pointer.pointee.modelMatrix = transform.modelMatrix
        pointer.pointee.normalMatrix = transform.normalMatrix
    }

    static func loadMesh(name: String) -> MDLMesh? {
        let assetURL = Bundle.main.url(forResource: name, withExtension: "obj")!
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let asset = MDLAsset(url: assetURL,
                             vertexDescriptor: mdlVertexDescriptor,
                             bufferAllocator: allocator)
        let mdlMesh = asset.object(at: 0) as! MDLMesh
        return mdlMesh
    }

    static func makePipelineState(vertex: MTLFunction,
                                  fragment: MTLFunction) -> MTLRenderPipelineState {

        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertex
        pipelineDescriptor.fragmentFunction = fragment

        pipelineDescriptor.vertexDescriptor = Morph.mtlVertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        do {
            pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }

}


extension Morph: Texturable {}

extension Morph: Renderable {
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
        guard let submesh = submesh else { return }
        var uniforms = vertex
        uniforms.modelMatrix = worldTransform
        uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

        renderEncoder.setRenderPipelineState(pipelineState)

        renderEncoder.setVertexBytes(&uniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(BufferIndexUniforms.rawValue))
        renderEncoder.setVertexBuffer(instanceBuffer, offset: 0,
                                      index: Int(BufferIndexInstances.rawValue))

        // set vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)


        renderEncoder.setFragmentTexture(baseColorTexture, index: 0)
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: submesh.indexBuffer.offset,
                                            instanceCount:  instanceCount)
    }
}
